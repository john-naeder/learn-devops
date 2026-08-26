#!/usr/bin/env bash
# Trọng tài của lab tuần 11. Không đọc một dòng .tf nào.
#
# Lab này chấm HAI vế, và vế thứ nhất chấm trước: (1) QUYẾT ĐỊNH — nhãn chiến
# lược bạn KHAI và hai con số RTO/RPO bạn HỨA có khớp nhau và có đạt bảng cam
# kết không; (2) HIỆN THỰC — hạ tầng bạn DỰNG có làm được điều bạn hứa không.
# Khai `pilot_light` rồi chỉ bật sao lưu là trượt. Khai `backup_restore` với RTO
# 30 phút cũng trượt — không phải vì hạ tầng sai, mà vì lời hứa không thuộc về
# chiến lược đã chọn.
#
# Script này CÓ GHI, và đó là ngoại lệ có chủ ý — một kế hoạch DR chưa từng thử
# nghiệm không phải là một kế hoạch. Nó đặt tệp thử dưới tiền tố
# self-w11-verify/, XOÁ THẬT một tệp rồi đòi lấy lại nội dung cũ, và ÉP tín hiệu
# sự cố đổi trạng thái rồi TRẢ VỀ như cũ. Nó dọn sạch tệp thử ở CẢ HAI kho,
# không sửa dòng cấu hình nào, và chạy lại nhiều lần cho cùng kết quả. Ba vòng
# chờ theo thời gian thật, mỗi vòng hạn 5 phút và in tiến độ.
set -uo pipefail
cd "$(dirname "$0")" || exit 1
source ../_lib/check.sh

PROFILE="${LAB_PROFILE:-lab-builder}" # danh tính có permission boundary gắn sẵn
export AWS_REGION="us-east-1"
export AWS_DEFAULT_REGION="us-east-1"

check_init "Tuần 11 — Bạn khai chiến lược DR nào, và bạn có dựng đúng cái đó không"

# --- Hợp đồng output: tám cái LUÔN bắt buộc ---------------------------------
CHIEN_LUOC=$(need_output chien_luoc_dr) || exit 1
RTO=$(need_output rto_phut) || exit 1
RPO=$(need_output rpo_phut) || exit 1
KHO_CHINH=$(need_output kho_chinh) || exit 1
KHO_PHU=$(need_output kho_du_phong) || exit 1
RUNBOOK=$(need_output duong_dan_runbook) || exit 1
BANG=$(need_output bang_giao_dich) || exit 1
CHI_PHI=$(need_output chi_phi) || exit 1

# --- Hai output CÓ ĐIỀU KIỆN ------------------------------------------------
# Chỉ đòi từ pilot_light trở lên. Gọi need_output cho chúng khi người học khai
# backup_restore là giết cả bài oan: backup_restore không hứa có tín hiệu sự cố
# và không hứa có năng lực tính toán chờ sẵn.
CANH_BAO=""
NHOM=""
case "$CHIEN_LUOC" in
pilot_light | warm_standby | multi_site)
  CANH_BAO=$(need_output ten_canh_bao_su_co) || exit 1
  NHOM=$(need_output nhom_den_moi) || exit 1
  ;;
esac

# --- Một output TUỲ CHỌN ----------------------------------------------------
# Đọc MỀM, không bao giờ qua need_output: bỏ trống là hợp lệ và không bị trừ
# điểm. Health check ở tầng DNS tốn $0,50/tháng và đề bài không bắt bạn mua nó.
MA_DNS="$(terraform -chdir=terraform output -no-color -raw ma_tin_hieu_dns 2>/dev/null)"
case "$MA_DNS" in *"No outputs found"*) MA_DNS="" ;; esac

echo
echo "  chi_phi = $CHI_PHI"
echo
echo "  Bạn khai: $CHIEN_LUOC · RTO ${RTO} phút · RPO ${RPO} phút"
echo "  Kho chính: $KHO_CHINH   ·   Kho dự phòng: $KHO_PHU"
echo "  (verify ghi tệp thử, xoá thật một tệp và ép tín hiệu sự cố đổi trạng thái"
echo "   — khoảng 5–10 phút, có báo tiến độ suốt)"

TAM=$(mktemp -d)
DAU="w11-$$-$RANDOM"
TIEN_TO="self-w11-verify/"
CANH_BAO_TRA_LAI="" # tên cảnh báo đang bị ép đổi trạng thái, rỗng khi không có
TRANG_THAI_CU=""

# --- Công cụ ----------------------------------------------------------------
la_so() { case "${1:-}" in '' | *[!0-9]*) return 1 ;; *) return 0 ;; esac; }

trong_khoang() { la_so "$1" && [ "$1" -ge "$2" ] && [ "$1" -le "$3" ]; }
epoch_cua() { date -u -d "${1:-}" +%s 2>/dev/null; }
doc_object() { # <kho> <key> <tệp đích>
  aws --profile "$PROFILE" s3api get-object --bucket "$1" --key "$2" "$3" >/dev/null 2>&1
}

# dem_tai_nguyen <region> [loại...] -> số tài nguyên mang tag lab=w11
dem_tai_nguyen() {
  local vung="$1" kq
  shift
  kq=$(aws --profile "$PROFILE" resourcegroupstaggingapi get-resources --region "$vung" \
    --tag-filters "Key=lab,Values=w11" --resource-type-filters "$@" \
    --query 'length(ResourceTagMappingList)' --output text 2>/dev/null)
  case "${kq:-}" in '' | None) printf '0' ;; *) printf '%s' "$kq" ;; esac
}

# don_kho <kho> — xoá MỌI phiên bản và delete marker dưới tiền tố thử. Kho bật
# lịch sử phiên bản thì "xoá" chỉ thêm marker, nên phải xoá theo version-id và
# phải quét cả hai danh sách. Đó cũng đúng là bài học của yêu cầu 2.
don_kho() {
  local kho="${1:-}" phan k v
  [ -z "$kho" ] && return 0
  for phan in Versions DeleteMarkers; do
    aws --profile "$PROFILE" s3api list-object-versions --bucket "$kho" --prefix "$TIEN_TO" \
      --query "${phan}[].[Key,VersionId]" --output text 2>/dev/null |
      while read -r k v; do
        if [ -z "${k:-}" ] || [ "$k" = "None" ]; then continue; fi
        aws --profile "$PROFILE" s3api delete-object --bucket "$kho" \
          --key "$k" --version-id "$v" >/dev/null 2>&1
      done
  done
}

# Dọn dẹp — chạy cả khi thoát giữa chừng hoặc khi có check hỏng. Trả lại trạng
# thái tín hiệu sự cố là BẮT BUỘC: verify không được để hệ thống của bạn nằm
# lại trong một báo động giả.
don_dep() {
  if [ -n "$CANH_BAO_TRA_LAI" ]; then
    aws --profile "$PROFILE" cloudwatch set-alarm-state --alarm-name "$CANH_BAO_TRA_LAI" \
      --state-value "${TRANG_THAI_CU:-OK}" \
      --state-reason "verify.sh w11 tra lai trang thai cu" >/dev/null 2>&1
    CANH_BAO_TRA_LAI=""
  fi
  don_kho "$KHO_CHINH"
  don_kho "$KHO_PHU"
  rm -rf "$TAM"
}
trap don_dep EXIT

# ---------------------------------------------------------------------------
section "1. Quyết định — ba tầng phải khớp nhau (yêu cầu 1)"

case "$CHIEN_LUOC" in
backup_restore | pilot_light | warm_standby | multi_site)
  ok "chien_luoc_dr là một trong bốn chiến lược DR" "$CHIEN_LUOC" ;;
*)
  fail "chien_luoc_dr là một trong bốn chiến lược DR" \
    "backup_restore | pilot_light | warm_standby | multi_site" \
    "${CHIEN_LUOC:-<rỗng>} — mọi check sau đều rẽ nhánh theo giá trị này" ;;
esac

if la_so "$RTO" && la_so "$RPO"; then
  ok "rto_phut và rpo_phut là số nguyên phút" "RTO=$RTO RPO=$RPO"
else
  fail "rto_phut và rpo_phut là số nguyên phút" "hai số nguyên, đơn vị phút" \
    "RTO=${RTO:-<rỗng>} RPO=${RPO:-<rỗng>} — verify so sánh bằng SỐ, không đoán chữ"
fi

# Quy RPO ra giây MỘT lần: rpo_phut không phải số thì mọi phép so sánh thời
# gian bên dưới vô nghĩa, và 0 giây là con số làm chúng hỏng cho đúng.
if la_so "$RPO"; then RPO_GIAY=$((RPO * 60)); else RPO_GIAY=0; fi

# --- Tầng (a): hai con số có đạt bảng cam kết của đề bài không --------------
if la_so "$RTO" && [ "$RTO" -le 60 ]; then
  ok "RTO cam kết đạt yêu cầu của giám đốc vận hành" "${RTO} phút (trần 60)"
else
  fail "RTO cam kết đạt yêu cầu của giám đốc vận hành" "rto_phut <= 60" \
    "${RTO:-?} — \"chạy lại trong vòng một tiếng. Không hơn.\""
fi

if la_so "$RPO" && [ "$RPO" -le 15 ]; then
  ok "RPO cam kết đạt yêu cầu về dữ liệu giao dịch" "${RPO} phút (trần 15)"
else
  fail "RPO cam kết đạt yêu cầu về dữ liệu giao dịch" "rpo_phut <= 15" \
    "${RPO:-?} — vé đã bán mà mất là tiền thật, không phải dữ liệu thật"
fi

# --- Tầng (b): hai con số có nằm trong dải KHẢ THI của chiến lược không -----
# Dải lấy từ bảng bốn chiến lược trong DOI-CHIEU.md và docs/aws/w11-dr-hybrid.md
# §2. Đây là chỗ "khai backup_restore với RTO 30 phút" trượt.
case "$CHIEN_LUOC" in
backup_restore) RPO_MIN=5 RPO_MAX=1440 RTO_MIN=60 RTO_MAX=2880 ;;
pilot_light) RPO_MIN=1 RPO_MAX=60 RTO_MIN=10 RTO_MAX=240 ;;
warm_standby) RPO_MIN=1 RPO_MAX=15 RTO_MIN=5 RTO_MAX=60 ;;
multi_site) RPO_MIN=0 RPO_MAX=5 RTO_MIN=0 RTO_MAX=5 ;;
*) RPO_MIN=0 RPO_MAX=0 RTO_MIN=0 RTO_MAX=0 ;;
esac

if trong_khoang "$RPO" "$RPO_MIN" "$RPO_MAX"; then
  ok "RPO cam kết nằm trong dải khả thi của $CHIEN_LUOC" "${RPO} phút (dải ${RPO_MIN}..${RPO_MAX})"
else
  fail "RPO cam kết nằm trong dải khả thi của $CHIEN_LUOC" "${RPO_MIN}..${RPO_MAX} phút" \
    "${RPO:-?} — hoặc bạn hứa nhiều hơn chiến lược này làm được, hoặc bạn dán nhầm nhãn cho thứ mình dựng"
fi

if trong_khoang "$RTO" "$RTO_MIN" "$RTO_MAX"; then
  ok "RTO cam kết nằm trong dải khả thi của $CHIEN_LUOC" "${RTO} phút (dải ${RTO_MIN}..${RTO_MAX})"
else
  fail "RTO cam kết nằm trong dải khả thi của $CHIEN_LUOC" "${RTO_MIN}..${RTO_MAX} phút" \
    "${RTO:-?} — Backup & Restore không dựng lại xong trong 30 phút, và Multi-Site không cần tới một tiếng"
fi

# --- Tầng (c): hạ tầng THẬT có khớp chiến lược đã khai không ----------------
assert_ne "kho dự phòng là một kho KHÁC kho chính" "$KHO_CHINH" "$KHO_PHU"

case "$CHIEN_LUOC" in
pilot_light)
  CO_CB=$(aws --profile "$PROFILE" cloudwatch describe-alarms --alarm-names "$CANH_BAO" \
    --query 'length(MetricAlarms)' --output text 2>/dev/null)
  CO_NHOM=$(aws --profile "$PROFILE" autoscaling describe-auto-scaling-groups \
    --auto-scaling-group-names "$NHOM" --query 'length(AutoScalingGroups)' --output text 2>/dev/null)
  if [ "${CO_CB:-0}" = "1" ] && [ "${CO_NHOM:-0}" = "1" ]; then
    ok "hạ tầng có đủ hai mảnh mà pilot_light đòi" "tín hiệu sự cố + nhóm đèn mồi"
  else
    fail "hạ tầng có đủ hai mảnh mà pilot_light đòi" \
      "tồn tại thật: cảnh báo \"$CANH_BAO\" và nhóm \"$NHOM\"" \
      "cảnh báo=${CO_CB:-0} nhóm=${CO_NHOM:-0} — pilot_light được định nghĩa bằng thứ ĐÃ DỰNG SẴN và đang tắt. Chỉ bật sao lưu thôi thì cái bạn dựng là backup_restore, dù bạn gọi nó là gì"
  fi
  ;;
warm_standby | multi_site)
  DANG_CHAY=$(aws --profile "$PROFILE" autoscaling describe-auto-scaling-groups \
    --auto-scaling-group-names "$NHOM" \
    --query "length(AutoScalingGroups[0].Instances[?LifecycleState=='InService'])" \
    --output text 2>/dev/null)
  if [ "${DANG_CHAY:-0}" -ge 1 ] 2>/dev/null; then
    ok "$CHIEN_LUOC có năng lực tính toán ĐANG CHẠY ở phía dự phòng" "$DANG_CHAY máy InService"
  else
    fail "$CHIEN_LUOC có năng lực tính toán ĐANG CHẠY ở phía dự phòng" \
      ">= 1 máy InService trong nhóm \"$NHOM\"" \
      "${DANG_CHAY:-0} — và đây là chỗ hai chiến lược này TỰ LOẠI MÌNH khỏi bối cảnh: chúng được định nghĩa bằng thứ đang chạy, mà đang chạy nghĩa là tính tiền theo giờ, mà kế toán trưởng đã nói không. Một câu duy nhất trong Bối cảnh loại hai trong bốn chiến lược"
  fi
  ;;
backup_restore)
  ok "backup_restore không đòi năng lực tính toán chờ sẵn" \
    "verify bỏ qua ten_canh_bao_su_co và nhom_den_moi"
  ;;
esac

# ---------------------------------------------------------------------------
section "2. Tệp sống sót qua thao tác xoá của con người (yêu cầu 2)"

VER=$(aws --profile "$PROFILE" s3api get-bucket-versioning --bucket "$KHO_CHINH" \
  --query 'Status' --output text 2>/dev/null)
assert_eq "kho chính giữ lịch sử phiên bản" "Enabled" "${VER:-<chưa bật>}"

KEY_XOA="${TIEN_TO}xoa-nham-${DAU}.txt"
printf 'Anh su kien quy 4. Xoa nham luc 3 gio sang. Ma: %s\n' "$DAU" >"$TAM/goc.txt"
BAN_GOC=$(aws --profile "$PROFILE" s3api put-object --bucket "$KHO_CHINH" \
  --key "$KEY_XOA" --body "$TAM/goc.txt" --query 'VersionId' --output text 2>/dev/null)

if [ -n "${BAN_GOC:-}" ] && [ "${BAN_GOC:-None}" != "None" ]; then
  ok "ghi được tệp thử vào kho chính, và nó có số phiên bản" "version ${BAN_GOC:0:12}…"
else
  fail "ghi được tệp thử vào kho chính, và nó có số phiên bản" "put-object trả về một VersionId" \
    "${BAN_GOC:-<không ghi được>} — không có VersionId nghĩa là kho chưa bật lịch sử phiên bản, và từ nay mọi lần ghi đè là mất vĩnh viễn"
fi

# XOÁ THẬT, bằng lệnh xoá thường — đúng thao tác mà một người mệt sẽ gõ.
DA_XOA=$(aws --profile "$PROFILE" s3api delete-object --bucket "$KHO_CHINH" \
  --key "$KEY_XOA" --query 'DeleteMarker' --output text 2>/dev/null)
assert_eq "lệnh xoá thường chỉ đặt delete marker, không xoá dữ liệu" "True" "${DA_XOA:-False}"

assert_cmd_fail "PHỦ ĐỊNH — sau khi xoá, đọc bản hiện tại KHÔNG ra gì nữa" \
  aws --profile "$PROFILE" s3api get-object --bucket "$KHO_CHINH" --key "$KEY_XOA" /dev/null

if aws --profile "$PROFILE" s3api get-object --bucket "$KHO_CHINH" --key "$KEY_XOA" \
  --version-id "$BAN_GOC" "$TAM/lay-lai.txt" >/dev/null 2>&1 &&
  cmp -s "$TAM/goc.txt" "$TAM/lay-lai.txt"; then
  ok "lấy lại được ĐÚNG nội dung cũ sau khi tệp đã bị xoá" \
    "$(wc -c <"$TAM/lay-lai.txt") byte, khớp từng byte"
else
  fail "lấy lại được ĐÚNG nội dung cũ sau khi tệp đã bị xoá" \
    "đọc được phiên bản $BAN_GOC và nội dung khớp bản đã ghi" \
    "không đọc được hoặc nội dung khác — đây là câu của trưởng nhóm nội dung: xoá nhầm một thư mục ảnh sự kiện phải không bao giờ mất dữ liệu nữa"
fi

# ---------------------------------------------------------------------------
section "3. Bản sao thứ hai TỰ cập nhật (yêu cầu 3)"

VER_PHU=$(aws --profile "$PROFILE" s3api get-bucket-versioning --bucket "$KHO_PHU" \
  --query 'Status' --output text 2>/dev/null)
assert_eq "kho dự phòng cũng giữ lịch sử phiên bản" "Enabled" "${VER_PHU:-<chưa bật>}"

KEY_NHIP="${TIEN_TO}nhip-${DAU}.txt"
printf 'Hoa don PDF moi. Ma: %s. Luc: %s\n' "$DAU" "$(date -u +%FT%TZ)" >"$TAM/nhip.txt"
aws --profile "$PROFILE" s3api put-object --bucket "$KHO_CHINH" \
  --key "$KEY_NHIP" --body "$TAM/nhip.txt" >/dev/null 2>&1

# Cửa sổ chờ 5 phút — đúng bằng RPO của dữ liệu tệp trong bảng cam kết.
printf '    chờ tệp mới xuất hiện ở kho dự phòng '
DEN_NOI=0
TROI=0
while [ "$TROI" -lt 300 ]; do
  if aws --profile "$PROFILE" s3api head-object --bucket "$KHO_PHU" --key "$KEY_NHIP" >/dev/null 2>&1; then
    DEN_NOI=1
    break
  fi
  sleep 15
  TROI=$((TROI + 15))
  printf '.'
done
printf ' [%ds]\n' "$TROI"

if [ "$DEN_NOI" -eq 1 ]; then
  ok "tệp mới tự sang kho dự phòng, không ai bấm gì" "sau ${TROI}s (cửa sổ 300s)"
else
  fail "tệp mới tự sang kho dự phòng, không ai bấm gì" \
    "$KEY_NHIP có mặt ở $KHO_PHU trong 300 giây" \
    "không thấy — \"tự cập nhật\" nghĩa là không ai bấm gì và không có lịch chạy nào. Kiểm theo thứ tự: cả hai kho đã bật lịch sử phiên bản chưa, role sao chép có quyền ở CẢ HAI phía chưa, rule có ra đời TRƯỚC tệp này không"
fi

TT_SAO=$(aws --profile "$PROFILE" s3api head-object --bucket "$KHO_CHINH" --key "$KEY_NHIP" \
  --query 'ReplicationStatus' --output text 2>/dev/null)
assert_eq "kho chính tự báo trạng thái sao chép của tệp đó" "COMPLETED" \
  "${TT_SAO:-<không có trường này — object nằm ngoài phạm vi mọi rule>}"

# ---------------------------------------------------------------------------
section "4. Dữ liệu giao dịch khôi phục về điểm-thời-gian (yêu cầu 4)"

TT_BANG=$(aws --profile "$PROFILE" dynamodb describe-table --table-name "$BANG" \
  --query 'Table.TableStatus' --output text 2>/dev/null)
if [ "${TT_BANG:-}" != "ACTIVE" ]; then
  fail "kho dữ liệu giao dịch tồn tại và đang phục vụ" "ACTIVE" \
    "${TT_BANG:-không đọc được \"$BANG\"} — verify đọc mốc khôi phục thật qua API của kho này"
else
  ok "kho dữ liệu giao dịch tồn tại và đang phục vụ" "$BANG"

  # Không tin lời khai: đọc mốc khôi phục gần nhất rồi tự trừ với hiện tại.
  printf '    chờ mốc khôi phục gần nhất bắt kịp hiện tại '
  TRE=999999 TRANG="" MOC="" TROI=0
  while [ "$TROI" -lt 300 ]; do
    read -r TRANG MOC < <(aws --profile "$PROFILE" dynamodb describe-continuous-backups \
      --table-name "$BANG" \
      --query 'ContinuousBackupsDescription.PointInTimeRecoveryDescription.[PointInTimeRecoveryStatus,LatestRestorableDateTime]' \
      --output text 2>/dev/null)
    if [ "${TRANG:-}" = "ENABLED" ]; then
      E=$(epoch_cua "${MOC:-}")
      [ -n "$E" ] && TRE=$(($(date +%s) - E))
      [ "$TRE" -le "$RPO_GIAY" ] && break
    fi
    sleep 20
    TROI=$((TROI + 20))
    printf '.'
  done
  printf ' [%ds]\n' "$TROI"

  if [ "${TRANG:-}" != "ENABLED" ]; then
    fail "kho giao dịch khôi phục được về một thời điểm BẤT KỲ" \
      "cơ chế khôi phục liên tục ở trạng thái ENABLED trên $BANG" \
      "${TRANG:-DISABLED} — ảnh chụp theo lịch chỉ cho RPO bằng đúng khoảng cách giữa hai lần chạy, mà bạn đang cam kết ${RPO} phút. Không có cơ chế liên tục thì con số đó là lời hứa suông"
  else
    ok "kho giao dịch khôi phục được về một thời điểm BẤT KỲ" "ENABLED"
    if [ "$TRE" -le "$RPO_GIAY" ] 2>/dev/null; then
      ok "độ trễ THẬT của cơ chế nằm trong RPO bạn cam kết" \
        "mốc gần nhất cách đây ${TRE}s, trần ${RPO_GIAY}s"
    else
      fail "độ trễ THẬT của cơ chế nằm trong RPO bạn cam kết" \
        "mốc khôi phục gần nhất cách hiện tại <= ${RPO_GIAY}s" \
        "cách đây ${TRE}s (mốc ${MOC:-?}) — cơ chế này không bao giờ cho mốc bằng \"ngay bây giờ\", nó luôn trễ một nhịp. Cam kết một con số nhỏ hơn độ trễ vốn có thì SỐ SAI, không phải hạ tầng sai"
    fi
  fi
fi

# ---------------------------------------------------------------------------
section "5. Runbook sống sót cùng sự cố (yêu cầu 5)"

CO_CHINH=0
CO_PHU=0
doc_object "$KHO_CHINH" "$RUNBOOK" "$TAM/rb-chinh.txt" && [ -s "$TAM/rb-chinh.txt" ] && CO_CHINH=1
doc_object "$KHO_PHU" "$RUNBOOK" "$TAM/rb-phu.txt" && [ -s "$TAM/rb-phu.txt" ] && CO_PHU=1

if [ "$CO_CHINH" -eq 1 ]; then
  ok "runbook có mặt ở kho chính" "s3://$KHO_CHINH/$RUNBOOK ($(wc -c <"$TAM/rb-chinh.txt") byte)"
else
  fail "runbook có mặt ở kho chính" "đọc được object $RUNBOOK ở $KHO_CHINH" \
    "không đọc được — quy trình chuyển vùng phải nằm ở dạng tệp trong kho dữ liệu, không nằm trên wiki"
fi

if [ "$CO_PHU" -eq 1 ]; then
  ok "runbook CÒN có mặt ở kho dự phòng" "s3://$KHO_PHU/$RUNBOOK"
else
  fail "runbook CÒN có mặt ở kho dự phòng" "đọc được object $RUNBOOK ở $KHO_PHU" \
    "không đọc được — đây là câu của người trực đêm hôm đó. Một runbook chỉ tồn tại ở nơi vừa chết thì không phải runbook, chỉ là một kỷ niệm. Nhớ: cơ chế sao chép chỉ áp cho object tạo SAU khi rule ra đời"
fi

for BAN in "chính:$CO_CHINH:$TAM/rb-chinh.txt" "dự phòng:$CO_PHU:$TAM/rb-phu.txt"; do
  NOI="${BAN%%:*}"
  CO="${BAN#*:}" CO="${CO%%:*}"
  [ "$CO" -eq 1 ] || continue
  ND=$(cat "${BAN##*:}")
  THIEU=""
  for CAN in "$CHIEN_LUOC" "$RTO" "$RPO"; do
    case "$ND" in *"$CAN"*) ;; *) THIEU="$THIEU \"$CAN\"" ;; esac
  done
  if [ -z "$THIEU" ]; then
    ok "bản runbook ở kho $NOI ghi đủ chiến lược và hai con số" "$CHIEN_LUOC · RTO $RTO · RPO $RPO"
  else
    fail "bản runbook ở kho $NOI ghi đủ chiến lược và hai con số" \
      "chứa nguyên văn \"$CHIEN_LUOC\", \"$RTO\" và \"$RPO\"" \
      "thiếu:$THIEU — người trực lúc 3 giờ sáng cần biết mình đang chạy kịch bản nào, còn bao nhiêu phút, và được phép mất bao nhiêu dữ liệu"
  fi
done

if [ "$CO_CHINH" -eq 1 ]; then
  ND=$(cat "$TAM/rb-chinh.txt")
  SO_BUOC=$(printf '%s\n' "$ND" | grep -cE '^[[:space:]]*[0-9]+[.)]' 2>/dev/null)
  # "Theo thứ tự" là một yêu cầu thật, không phải cách nói: một runbook đánh số
  # 1, 2, 2, 5 là một runbook chưa ai đọc lại lần nào.
  TANG=1
  TRUOC=0
  while read -r N; do
    [ -z "${N:-}" ] && continue
    [ "$N" -le "$TRUOC" ] && TANG=0
    TRUOC="$N"
  done <<EOF
$(printf '%s\n' "$ND" | sed -nE 's/^[[:space:]]*([0-9]+)[.)].*/\1/p')
EOF

  if [ "${SO_BUOC:-0}" -ge 5 ] 2>/dev/null && [ "$TANG" -eq 1 ]; then
    ok "runbook có các bước đánh số, tăng dần" "$SO_BUOC bước, 1..$TRUOC"
  else
    fail "runbook có các bước đánh số, tăng dần" \
      ">= 5 dòng BẮT ĐẦU bằng số thứ tự, và dãy số tăng dần" \
      "${SO_BUOC:-0} bước, tăng dần=$TANG — người trực lúc 3 giờ sáng làm theo từng bước, không đọc văn xuôi; và đảo hai bước là đổi hẳn kết quả"
  fi
fi

# ---------------------------------------------------------------------------
if [ -n "$CANH_BAO" ]; then
  section "6. Tín hiệu sự cố đổi trạng thái được (yêu cầu 6)"

  read -r TRANG_THAI_CU THIEU_DL HANH_DONG < <(
    aws --profile "$PROFILE" cloudwatch describe-alarms --alarm-names "$CANH_BAO" \
      --query 'MetricAlarms[0].[StateValue,TreatMissingData,AlarmActions[0]]' --output text 2>/dev/null
  )

  if [ -z "${TRANG_THAI_CU:-}" ] || [ "${TRANG_THAI_CU:-None}" = "None" ]; then
    fail "có một tín hiệu sự cố mà MÁY đọc được" "một cảnh báo tên \"$CANH_BAO\"" \
      "không đọc được — một email gửi cho người không phải tín hiệu tự động: nó không đổi trạng thái, và không có gì đọc được nó lúc 3 giờ sáng"
  else
    ok "có một tín hiệu sự cố mà MÁY đọc được" "$CANH_BAO"

    if [ "$TRANG_THAI_CU" = "OK" ]; then
      ok "tín hiệu đang KHOẺ khi hệ thống bình thường" "OK"
    else
      fail "tín hiệu đang KHOẺ khi hệ thống bình thường" "OK" \
        "$TRANG_THAI_CU — INSUFFICIENT_DATA trông y hệt KHOẺ trên dashboard và sẽ không bao giờ kêu; ALARM nghĩa là hệ thống đang tự coi mình là hỏng"
    fi

    if [ -n "${HANH_DONG:-}" ] && [ "${HANH_DONG:-None}" != "None" ]; then
      ok "tín hiệu có nơi để gửi thông điệp đi" "$HANH_DONG"
    else
      fail "tín hiệu có nơi để gửi thông điệp đi" "ít nhất một alarm action" \
        "<không có> — một cảnh báo không gửi đi đâu chỉ đổi màu một ô trên dashboard mà 3 giờ sáng không ai mở"
    fi

    assert_eq "tín hiệu coi IM LẶNG là dấu hiệu XẤU" "breaching" "${THIEU_DL:-missing}"

    # --- MÔ PHỎNG SỰ CỐ ----------------------------------------------------
    # Từ đây trạng thái tín hiệu của bạn đang bị verify ép đổi. Biến dưới đây
    # bật cơ chế trả lại trong don_dep — kể cả khi check bên dưới hỏng, kể cả
    # khi bạn bấm Ctrl-C.
    CANH_BAO_TRA_LAI="$CANH_BAO"
    aws --profile "$PROFILE" cloudwatch set-alarm-state --alarm-name "$CANH_BAO" \
      --state-value ALARM --state-reason "verify.sh w11 mo phong su co Region chinh ($DAU)" \
      >/dev/null 2>&1

    printf '    chờ tín hiệu chuyển sang trạng thái hỏng '
    TT_MOI=""
    TROI=0
    while [ "$TROI" -lt 300 ]; do
      TT_MOI=$(aws --profile "$PROFILE" cloudwatch describe-alarms --alarm-names "$CANH_BAO" \
        --query 'MetricAlarms[0].StateValue' --output text 2>/dev/null)
      [ "${TT_MOI:-}" = "ALARM" ] && break
      sleep 10
      TROI=$((TROI + 10))
      printf '.'
    done
    printf ' [%ds, đang là %s]\n' "$TROI" "${TT_MOI:-?}"

    if [ "${TT_MOI:-}" = "ALARM" ]; then
      ok "tín hiệu chuyển sang HỎNG trong vòng 5 phút khi có sự cố" "ALARM sau ${TROI}s"
    else
      fail "tín hiệu chuyển sang HỎNG trong vòng 5 phút khi có sự cố" "ALARM trong 300 giây" \
        "${TT_MOI:-?} — một tín hiệu không đổi được trạng thái thì không phải tín hiệu, chỉ là một dòng cấu hình"
    fi

    # --- TRẢ LẠI TRẠNG THÁI CŨ — bắt buộc, kể cả khi check trên hỏng -------
    aws --profile "$PROFILE" cloudwatch set-alarm-state --alarm-name "$CANH_BAO" \
      --state-value "$TRANG_THAI_CU" \
      --state-reason "verify.sh w11 tra lai trang thai cu" >/dev/null 2>&1
    CANH_BAO_TRA_LAI=""
    TT_TRA=$(aws --profile "$PROFILE" cloudwatch describe-alarms --alarm-names "$CANH_BAO" \
      --query 'MetricAlarms[0].StateValue' --output text 2>/dev/null)
    assert_eq "verify trả tín hiệu về đúng trạng thái ban đầu" "$TRANG_THAI_CU" "${TT_TRA:-?}"
  fi
else
  section "6. Tín hiệu sự cố — không áp dụng"
  echo "    $CHIEN_LUOC không hứa có tín hiệu sự cố tự động: yêu cầu 6 chỉ bắt buộc"
  echo "    từ pilot_light trở lên. Bỏ qua, không trừ điểm."
fi

# ---------------------------------------------------------------------------
if [ -n "$NHOM" ]; then
  section "7. Năng lực tính toán đã khai báo nhưng đang TẮT (yêu cầu 7)"

  read -r MONG_MUON TOI_THIEU TOI_DA SO_MAY MAU < <(
    aws --profile "$PROFILE" autoscaling describe-auto-scaling-groups \
      --auto-scaling-group-names "$NHOM" \
      --query "AutoScalingGroups[0].[DesiredCapacity,MinSize,MaxSize,length(Instances),not_null(LaunchTemplate.LaunchTemplateName,MixedInstancesPolicy.LaunchTemplate.LaunchTemplateSpecification.LaunchTemplateName,LaunchConfigurationName,'None')]" \
      --output text 2>/dev/null
  )

  if [ -z "${MONG_MUON:-}" ] || [ "${MONG_MUON:-None}" = "None" ]; then
    fail "nhóm đèn mồi tồn tại" "một nhóm tên \"$NHOM\"" \
      "không đọc được — bạn khai $CHIEN_LUOC, và chữ \"đèn mồi\" nghĩa là bấc đã tẩm dầu sẵn"
  else
    ok "nhóm đèn mồi tồn tại" "$NHOM"
    assert_eq "sức chứa mong muốn đang là 0" "0" "$MONG_MUON"
    assert_eq "sức chứa tối thiểu đang là 0" "0" "$TOI_THIEU"
    assert_eq "PHỦ ĐỊNH — không một máy nào đang chạy trong nhóm" "0" "${SO_MAY:-0}"

    if [ "${TOI_DA:-0}" -ge 1 ] 2>/dev/null; then
      ok "bật lên được bằng MỘT thao tác" "max_size=$TOI_DA, chỉ cần đổi desired"
    else
      fail "bật lên được bằng MỘT thao tác" "max_size >= 1" \
        "${TOI_DA:-0} — một nhóm có trần bằng 0 thì không bao giờ châm lửa được; đó là bấc không có dầu"
    fi

    if [ -n "${MAU:-}" ] && [ "${MAU:-None}" != "None" ]; then
      ok "nhóm đã khai sẵn máy sẽ dựng ra trông thế nào" "$MAU"
    else
      fail "nhóm đã khai sẵn máy sẽ dựng ra trông thế nào" "một launch template gắn với nhóm" \
        "<không có> — \"năng lực tính toán ĐÃ KHAI BÁO\" nghĩa là lúc sự cố bạn chỉ đổi một con số, không phải ngồi nghĩ dùng AMI nào"
    fi
  fi
else
  section "7. Năng lực tính toán chờ sẵn — không áp dụng"
  echo "    $CHIEN_LUOC không hứa có năng lực tính toán chờ sẵn. Bỏ qua, không trừ điểm."
fi

# ---------------------------------------------------------------------------
section "8. PHỦ ĐỊNH — không gì trong lab này tính tiền theo giờ (yêu cầu 8)"

SO_MAY_CHAY=$(aws --profile "$PROFILE" ec2 describe-instances \
  --filters "Name=tag:lab,Values=w11" \
  "Name=instance-state-name,Values=pending,running,stopping,shutting-down" \
  --query 'length(Reservations[].Instances[])' --output text 2>/dev/null)
assert_eq "không máy chủ nào mang tag lab=w11 đang sống" "0" "${SO_MAY_CHAY:-0}"

assert_eq "không cơ sở dữ liệu quản lý / cache nào mang tag lab=w11" "0" \
  "$(dem_tai_nguyen us-east-1 rds elasticache)"
assert_eq "không cân bằng tải nào mang tag lab=w11" "0" \
  "$(dem_tai_nguyen us-east-1 elasticloadbalancing)"
assert_eq "không NAT / Elastic IP / Transit Gateway / VPN nào mang tag lab=w11" "0" \
  "$(dem_tai_nguyen us-east-1 ec2:natgateway ec2:elastic-ip ec2:transit-gateway ec2:vpn-connection)"

# Nếu bạn có mở rào hai Region thì đây là chỗ Region thứ hai bị soi. Rào đang
# đóng thì lệnh này bị từ chối và trả 0 — vẫn đúng, vì rào đóng nghĩa là
# lab-builder không tạo được gì ở đó.
assert_eq "không gì tính tiền theo giờ ở Region thứ hai (nếu bạn có mở rào)" "0" \
  "$(dem_tai_nguyen us-west-2 ec2:instance rds elasticloadbalancing ec2:natgateway)"

# ---------------------------------------------------------------------------
section "9. PHỦ ĐỊNH — không ai ngoài tài khoản đọc được dữ liệu (yêu cầu 9)"

# Kiểm CẢ HAI kho. Bài học nằm ở kho thứ hai: rất nhiều vụ lộ dữ liệu bắt đầu từ
# chỗ kho chính được siết kỹ còn kho backup thì không ai nhớ tới — dù nó là một
# bản sao ĐẦY ĐỦ của cùng dữ liệu ấy.
for KHO in "$KHO_CHINH" "$KHO_PHU"; do
  CHAN=$(aws --profile "$PROFILE" s3api get-public-access-block --bucket "$KHO" \
    --query 'join(`,`,[to_string(PublicAccessBlockConfiguration.BlockPublicAcls),to_string(PublicAccessBlockConfiguration.IgnorePublicAcls),to_string(PublicAccessBlockConfiguration.BlockPublicPolicy),to_string(PublicAccessBlockConfiguration.RestrictPublicBuckets)])' \
    --output text 2>/dev/null)
  assert_eq "$KHO chặn public đủ bốn công tắc" "true,true,true,true" "${CHAN:-<chưa đặt>}"

  assert_cmd_fail "PHỦ ĐỊNH — không credential thì không đọc được runbook ở $KHO" \
    aws --profile "$PROFILE" s3api get-object --no-sign-request \
    --bucket "$KHO" --key "$RUNBOOK" /dev/null

  assert_cmd_fail "PHỦ ĐỊNH — không credential thì không liệt kê được $KHO" \
    aws --profile "$PROFILE" s3api list-objects-v2 --no-sign-request --bucket "$KHO"
done

# ---------------------------------------------------------------------------
section "10. Tuỳ chọn — tín hiệu ở tầng DNS (ma_tin_hieu_dns)"

if [ -z "$MA_DNS" ]; then
  echo "    bỏ qua: bạn không khai ma_tin_hieu_dns. Đây là output TUỲ CHỌN, bỏ trống"
  echo "    KHÔNG bị trừ điểm — health check tốn \$0,50/tháng và đề bài không bắt bạn"
  echo "    mua nó; một cảnh báo CloudWatch thoả yêu cầu 6 với giá \$0."
else
  read -r HC_LOAI HC_TAT HC_DAO HC_NHIP HC_NGUONG < <(
    aws --profile "$PROFILE" route53 get-health-check --health-check-id "$MA_DNS" \
      --query 'HealthCheck.HealthCheckConfig.[Type,Disabled,Inverted,RequestInterval,FailureThreshold]' \
      --output text 2>/dev/null
  )

  if [ -n "${HC_LOAI:-}" ] && [ "${HC_LOAI:-None}" != "None" ]; then
    ok "tín hiệu ở tầng DNS tồn tại thật" "$HC_LOAI (id $MA_DNS)"
  else
    fail "tín hiệu ở tầng DNS tồn tại thật" "một health check id $MA_DNS" \
      "không đọc được — nếu bạn đã xoá nó thì bỏ luôn output ma_tin_hieu_dns đi, nó là tuỳ chọn"
  fi

  assert_eq "tín hiệu DNS đang bật và không bị đảo ngược ý nghĩa" "False False" \
    "${HC_TAT:-?} ${HC_DAO:-?} — health check bị tắt thì luôn báo khoẻ mà vẫn tính tiền, còn bị đảo thì báo ngược"

  if la_so "${HC_NHIP:-}" && la_so "${HC_NGUONG:-}" && [ $((HC_NHIP * HC_NGUONG)) -le 90 ]; then
    ok "thời gian phát hiện nằm trọn trong RTO cam kết" "${HC_NHIP}s x ${HC_NGUONG} lần"
  else
    fail "thời gian phát hiện nằm trọn trong RTO cam kết" \
      "RequestInterval x FailureThreshold <= 90 giây" \
      "${HC_NHIP:-?} x ${HC_NGUONG:-?} — đồng hồ RTO chạy từ lúc SỰ CỐ XẢY RA, không phải từ lúc bạn biết"
  fi
  echo "    nhắc: health check KHÔNG mang tag như các dịch vụ khác nên find-orphans.sh"
  echo "    có thể không thấy nó, và nó tốn \$0,50/tháng — mãi mãi."
fi

# ---------------------------------------------------------------------------
if summary; then
  cat <<'EOF'

Hai câu tự hỏi trước khi đọc DOI-CHIEU.md:

  1. Hai kho của bạn đang nằm trong CÙNG một Region — đúng cái Region mà kịch
     bản giả định là đã chết. Bản sao thứ hai cứu bạn khỏi ba loại sự cố và bó
     tay trước loại thứ tư. Kể tên bốn loại đó, rồi nói con số RPO bạn vừa cam
     kết sẽ đổi thế nào nếu kho thứ hai nằm ở một Region khác.

  2. verify.sh vừa chứng minh bạn CÓ đủ thứ để khôi phục. Nó không chứng minh
     được bạn KHÔI PHỤC ĐƯỢC trong 60 phút. Hai việc đó cách nhau bao xa, và
     làm sao biết con số RTO bạn khai là số đo chứ không phải ước lượng?
     (Gợi ý: có một hoạt động mà mọi đội DR trưởng thành đều làm định kỳ, và nó
     có tên riêng.)
EOF
fi
