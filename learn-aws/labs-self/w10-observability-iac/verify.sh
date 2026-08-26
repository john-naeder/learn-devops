#!/usr/bin/env bash
# Trọng tài của lab tuần 10.
#
# Không đọc một dòng .tf nào. Lab này KHÔNG chỉ đọc: một cảnh báo chỉ được coi
# là cảnh báo khi nó đã kêu ít nhất một lần, nên script này cố tình đẩy hệ thống
# của bạn vào trạng thái lỗi rồi ngồi chờ xem có ai được báo động không.
#
# Ba thứ được quan sát theo thời gian thật, mỗi thứ có hạn giờ rõ ràng và in
# tiến độ — không có vòng chờ nào là vô hạn:
#   - số đo lỗi xuất hiện (và bằng 0) khi hệ thống khoẻ
#   - cảnh báo chuyển OK -> ALARM sau 2 chu kỳ lỗi liên tiếp
#   - thông điệp cảnh báo thật sự tới được hộp thư của người trực
#
# Nó gọi hàm của bạn và vét hộp thư trực. Nó KHÔNG sửa cấu hình nào. Chạy lại
# nhiều lần cho cùng kết quả.
set -uo pipefail
cd "$(dirname "$0")" || exit 1
source ../_lib/check.sh

export AWS_PROFILE="${LAB_PROFILE:-lab-builder}"
export AWS_REGION="us-east-1"
export AWS_DEFAULT_REGION="us-east-1"

check_init "Tuần 10 — Cảnh báo phải kêu, và phải kêu tới được người trực"

HAM=$(need_output ten_ham)             || exit 1
LG=$(need_output nhom_nhat_ky)         || exit 1
NS=$(need_output so_do_khong_gian)     || exit 1
MT=$(need_output so_do_ten)            || exit 1
CB=$(need_output ten_canh_bao)         || exit 1
HT=$(need_output hop_thu_truc)         || exit 1
TQ=$(need_output ten_truy_van)         || exit 1
KHO=$(need_output kho_state)           || exit 1
DUONG=$(need_output duong_dan_state)   || exit 1
BANG=$(need_output bang_khoa_state)    || exit 1

DAU="w10-$$-$RANDOM"

# ---------------------------------------------------------------------------
# Công cụ
# ---------------------------------------------------------------------------

iso() { date -u -d "@$1" +%Y-%m-%dT%H:%M:%SZ; }

# goi_ham <che_do> <ma_yeu_cau> [ms]
goi_ham() {
  local che_do="$1" ma="$2" ms="${3:-1500}" than
  if [ "$che_do" = "cham" ]; then
    than="{\"che_do\":\"cham\",\"ma_yeu_cau\":\"$ma\",\"ms\":$ms}"
  else
    than="{\"che_do\":\"$che_do\",\"ma_yeu_cau\":\"$ma\"}"
  fi
  aws lambda invoke --function-name "$HAM" \
    --cli-binary-format raw-in-base64-out \
    --payload "$than" /dev/null >/dev/null 2>&1
}

# so_do <epoch-bat-dau> -> "<so_diem> <tong>"  (tổng là None nếu chưa có điểm nào)
so_do() {
  local t0="$1" t1
  t1=$(( $(date +%s) + 60 ))
  aws cloudwatch get-metric-statistics \
    --namespace "$NS" --metric-name "$MT" \
    --start-time "$(iso "$t0")" --end-time "$(iso "$t1")" \
    --period 60 --statistics Sum \
    --query 'join(` `,[to_string(length(Datapoints)),to_string(sum(Datapoints[].Sum))])' \
    --output text 2>/dev/null
}

trang_thai() {
  aws cloudwatch describe-alarms --alarm-names "$CB" \
    --query 'MetricAlarms[0].StateValue' --output text 2>/dev/null
}

# cho_trang_thai <mong doi> <han giay> -> 0 nếu tới đúng trạng thái trong hạn
cho_trang_thai() {
  local mong="$1" han="$2" troi=0 tt
  printf '    chờ cảnh báo về trạng thái %s ' "$mong"
  while [ "$troi" -lt "$han" ]; do
    tt=$(trang_thai)
    if [ "$tt" = "$mong" ]; then printf ' %s [%ds]\n' "$tt" "$troi"; return 0; fi
    sleep 15
    troi=$((troi + 15))
    printf '.'
  done
  printf ' [hết %ds, đang là %s]\n' "$han" "$(trang_thai)"
  return 1
}

# Tách JSON của ReceiveMessage: dòng 1 FOUND/NOTFOUND, các dòng sau là ReceiptHandle.
_doc() {
  python3 -c '
import sys, json
can = sys.argv[1]
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
msgs = d.get("Messages") or []
print("FOUND" if any(can in (m.get("Body") or "") for m in msgs) else "NOTFOUND")
for m in msgs:
    print(m.get("ReceiptHandle", ""))
' "$1"
}

# hut_hop_thu <chuoi can tim> <giay cho> -> FOUND/NOTFOUND, xoá mọi thứ nhận được
hut_hop_thu() {
  local can="${1:--khong-tim-gi-}" cho="$2" kq h
  kq=$(aws sqs receive-message --queue-url "$HT" --max-number-of-messages 10 \
    --visibility-timeout 0 --wait-time-seconds "$cho" --output json 2>/dev/null | _doc "$can")
  [ -z "$kq" ] && { echo NOTFOUND; return 0; }
  printf '%s\n' "$kq" | tail -n +2 | while IFS= read -r h; do
    [ -n "$h" ] && aws sqs delete-message --queue-url "$HT" --receipt-handle "$h" >/dev/null 2>&1
  done
  printf '%s\n' "$kq" | head -1
}

echo
echo "  (verify.sh gọi hàm của bạn ~15 lần và chờ cảnh báo kêu — mất khoảng 10 phút)"

# ---------------------------------------------------------------------------
section "1. Dịch vụ có nói cho ta biết nó đang làm gì (yêu cầu 1, 2)"
# ---------------------------------------------------------------------------

GIU=$(aws logs describe-log-groups --log-group-name-prefix "$LG" \
  --query "logGroups[?logGroupName=='$LG'].retentionInDays | [0]" --output text 2>/dev/null)

if [ -n "$GIU" ] && [ "$GIU" != "None" ] && [ "$GIU" -le 7 ] 2>/dev/null; then
  ok "nhật ký có hạn giữ, không quá 7 ngày" "${GIU} ngày"
elif [ "$GIU" = "None" ]; then
  fail "nhật ký có hạn giữ, không quá 7 ngày" \
    "1..7 ngày" "chưa đặt hạn — nhóm nhật ký này giữ VĨNH VIỄN và tính tiền mãi mãi"
else
  fail "nhật ký có hạn giữ, không quá 7 ngày" "1..7 ngày" "${GIU:-<không tìm thấy nhóm nhật ký>}"
fi

T0=$(( $(date +%s) - 60 ))
SO_GOI_OK=0
for i in 1 2 3; do
  goi_ham binh_thuong "$DAU-thuong-$i" && SO_GOI_OK=$((SO_GOI_OK + 1))
done
goi_ham cham "$DAU-cham-1" 1500 && SO_GOI_OK=$((SO_GOI_OK + 1))
goi_ham cham "$DAU-cham-2" 2500 && SO_GOI_OK=$((SO_GOI_OK + 1))

assert_eq "gọi được hàm ở cả hai chế độ bình thường và chậm" "5" "$SO_GOI_OK"

printf '    chờ nhật ký hiện ra '
CO_LOG=0
TROI=0
while [ "$TROI" -lt 150 ]; do
  SO_DONG=$(aws logs filter-log-events --log-group-name "$LG" \
    --start-time "$((T0 * 1000))" --filter-pattern "$DAU" \
    --query 'length(events)' --output text 2>/dev/null)
  if [ -n "$SO_DONG" ] && [ "$SO_DONG" != "None" ] && [ "$SO_DONG" -ge 5 ] 2>/dev/null; then
    CO_LOG=$SO_DONG
    break
  fi
  sleep 10
  TROI=$((TROI + 10))
  printf '.'
done
printf ' [%ds]\n' "$TROI"

if [ "$CO_LOG" -ge 5 ] 2>/dev/null; then
  ok "mỗi lệnh gọi để lại đúng một dòng nhật ký" "$CO_LOG dòng mang mã của lần chạy này"
else
  fail "mỗi lệnh gọi để lại đúng một dòng nhật ký" \
    ">= 5 dòng chứa \"$DAU\" trong $LG" \
    "${CO_LOG:-0} dòng sau 150 giây — hàm chưa ghi log, ghi sai nhóm, hoặc không chép lại ma_yeu_cau"
fi

# ---------------------------------------------------------------------------
section "2. Nhật ký trở thành con số, và con số đó là 0 khi khoẻ (yêu cầu 3)"
# ---------------------------------------------------------------------------

printf '    chờ số đo lỗi xuất hiện '
SO_DIEM=0
TONG="None"
TROI=0
while [ "$TROI" -lt 180 ]; do
  read -r SO_DIEM TONG < <(so_do "$T0")
  [ "${SO_DIEM:-0}" -ge 1 ] 2>/dev/null && break
  sleep 15
  TROI=$((TROI + 15))
  printf '.'
done
printf ' [%ds]\n' "$TROI"

if [ "${SO_DIEM:-0}" -ge 1 ] 2>/dev/null; then
  ok "số đo lỗi có dữ liệu ngay cả khi không có lỗi nào" "$SO_DIEM điểm dữ liệu"
else
  fail "số đo lỗi có dữ liệu ngay cả khi không có lỗi nào" \
    "ít nhất 1 điểm dữ liệu trên $NS/$MT" \
    "không có điểm nào — nhiều khả năng metric filter thiếu default_value = 0, nên khi không có lỗi thì KHÔNG CÓ DỮ LIỆU chứ không phải bằng 0"
fi

# NEGATIVE — gọi bình thường không được làm số đo lỗi nhúc nhích
case "$TONG" in
0 | 0.0 | None)
  ok "gọi ở chế độ bình thường KHÔNG làm số lỗi tăng" "tổng = ${TONG}"
  ;;
*)
  fail "gọi ở chế độ bình thường KHÔNG làm số lỗi tăng" \
    "tổng = 0" "tổng = $TONG — mẫu lọc của bạn đang bắt cả dòng INFO"
  ;;
esac

# ---------------------------------------------------------------------------
section "3. Lúc khoẻ thì im lặng, nhưng không im lặng vì mù (yêu cầu 5)"
# ---------------------------------------------------------------------------

read -r CHU_KY SO_CHU_KY DIEM_KEU THIEU_DL < <(
  aws cloudwatch describe-alarms --alarm-names "$CB" \
    --query 'MetricAlarms[0].[Period,EvaluationPeriods,DatapointsToAlarm,TreatMissingData]' \
    --output text 2>/dev/null)

[ "${DIEM_KEU:-None}" = "None" ] && DIEM_KEU="${SO_CHU_KY:-0}"

assert_eq "chu kỳ đánh giá là 60 giây" "60" "${CHU_KY:-<không đọc được cảnh báo>}"

if [ "${SO_CHU_KY:-0}" -ge 2 ] 2>/dev/null && [ "${DIEM_KEU:-0}" -ge 2 ] 2>/dev/null; then
  ok "phải lỗi ở 2 chu kỳ liên tiếp mới kêu" "evaluation=$SO_CHU_KY datapoints=$DIEM_KEU"
else
  fail "phải lỗi ở 2 chu kỳ liên tiếp mới kêu" \
    "evaluation_periods >= 2 VÀ datapoints_to_alarm >= 2" \
    "evaluation=${SO_CHU_KY:-?} datapoints=${DIEM_KEU:-?} — một lần lỗi thoáng qua sẽ đánh thức người trực lúc 2 giờ sáng"
fi

assert_ne "cách xử lý 'thiếu dữ liệu' không để mặc định" "missing" "${THIEU_DL:-missing}"

HANH_DONG=$(aws cloudwatch describe-alarms --alarm-names "$CB" \
  --query 'MetricAlarms[0].AlarmActions[0]' --output text 2>/dev/null)
assert_contains "cảnh báo có nơi để gửi thông điệp đi" ":sns:" "${HANH_DONG:-<không có hành động nào>}"

if [ "${HANH_DONG:-None}" != "None" ] && [ -n "${HANH_DONG:-}" ]; then
  SO_DK=$(aws sns list-subscriptions-by-topic --topic-arn "$HANH_DONG" \
    --query "length(Subscriptions[?SubscriptionArn!='PendingConfirmation'])" --output text 2>/dev/null)
  if [ "${SO_DK:-0}" -ge 1 ] 2>/dev/null; then
    ok "có ít nhất một người/hệ thống đã XÁC NHẬN nhận cảnh báo" "$SO_DK subscription đã xác nhận"
  else
    fail "có ít nhất một người/hệ thống đã XÁC NHẬN nhận cảnh báo" \
      ">= 1 subscription không ở trạng thái PendingConfirmation" \
      "${SO_DK:-0} — nếu bạn đăng ký bằng email thì phải mở hộp thư bấm xác nhận; Terraform không bấm hộ được"
  fi
fi

TT=$(trang_thai)
if [ "$TT" = "ALARM" ]; then
  echo "    cảnh báo đang kêu từ lần chạy trước — chờ nó tự nguôi"
  if cho_trang_thai OK 360; then
    ok "cảnh báo tự về trạng thái khoẻ khi hết lỗi" "OK"
  else
    fail "cảnh báo tự về trạng thái khoẻ khi hết lỗi" \
      "OK trong 360 giây" "vẫn là $(trang_thai)"
  fi
else
  assert_eq "lúc hệ thống khoẻ, cảnh báo im lặng và KHÔNG mù" "OK" "$TT"
fi

# ---------------------------------------------------------------------------
section "4. Đẩy hệ thống vào trạng thái lỗi (yêu cầu 4)"
# ---------------------------------------------------------------------------

echo "    vét hộp thư trực trước khi thí nghiệm"
for _ in 1 2 3 4 5; do
  [ "$(hut_hop_thu - 1)" = "NOTFOUND" ] && break
done

T_LOI=$(( $(date +%s) - 30 ))
printf '    gây lỗi chu kỳ 1 '
for i in 1 2 3 4; do goi_ham loi "$DAU-loi-a$i" && printf 'x'; done
printf '\n    chờ sang chu kỳ sau '
sleep 65
printf '[65s]\n'
printf '    gây lỗi chu kỳ 2 '
for i in 1 2 3 4; do goi_ham loi "$DAU-loi-b$i" && printf 'x'; done
printf '\n'

if cho_trang_thai ALARM 480; then
  ok "cảnh báo KÊU sau 2 chu kỳ lỗi liên tiếp" "ALARM"
else
  fail "cảnh báo KÊU sau 2 chu kỳ lỗi liên tiếp" \
    "ALARM trong 480 giây kể từ khi bắt đầu gây lỗi" \
    "vẫn là $(trang_thai) — kiểm tra ngưỡng (>= 3 lỗi/chu kỳ), comparison_operator, và mẫu lọc có bắt đúng dòng ERROR không"
fi

read -r SO_DIEM_LOI TONG_LOI < <(so_do "$T_LOI")
if [ "${TONG_LOI:-None}" != "None" ] && [ "${TONG_LOI%%.*}" -ge 6 ] 2>/dev/null; then
  ok "8 lỗi nghiệp vụ được đếm thành số" "tổng = $TONG_LOI trên $SO_DIEM_LOI điểm"
else
  fail "8 lỗi nghiệp vụ được đếm thành số" \
    "tổng >= 6 trên $NS/$MT" \
    "tổng = ${TONG_LOI:-None} — mẫu lọc chưa bắt được dòng có muc = ERROR"
fi

# ---------------------------------------------------------------------------
section "5. Cảnh báo tới được người trực (yêu cầu 4)"
# ---------------------------------------------------------------------------

printf '    canh hộp thư trực '
DEN=0
TROI=0
while [ "$TROI" -lt 240 ]; do
  if [ "$(hut_hop_thu "$CB" 10)" = "FOUND" ]; then DEN=1; break; fi
  TROI=$((TROI + 10))
  printf '.'
done
printf ' [%ds]\n' "$TROI"

if [ "$DEN" -eq 1 ]; then
  ok "thông điệp cảnh báo thật sự nằm trong hộp thư trực" "sau ~${TROI}s"
else
  fail "thông điệp cảnh báo thật sự nằm trong hộp thư trực" \
    "một thông điệp có chứa \"$CB\" trong $HT" \
    "không thấy sau 240 giây — cảnh báo có kêu nhưng thông điệp không tới nơi. Kiểm tra: hộp thư đã đăng ký với kênh thông báo chưa, và kênh có được phép đẩy vào hộp thư không (resource policy)"
fi

# ---------------------------------------------------------------------------
section "6. Truy vấn đã lưu, không phải gõ lại lúc 2 giờ sáng (yêu cầu 6)"
# ---------------------------------------------------------------------------

CAU=$(aws logs describe-query-definitions --query-definition-name-prefix "$TQ" \
  --query "queryDefinitions[?name=='$TQ'].queryString | [0]" --output text 2>/dev/null)

if [ -z "$CAU" ] || [ "$CAU" = "None" ]; then
  fail "truy vấn được lưu sẵn trong hệ thống" \
    "một query definition tên \"$TQ\"" \
    "không tìm thấy — gõ lại truy vấn giữa lúc sự cố là cách mất thêm 10 phút"
else
  ok "truy vấn được lưu sẵn trong hệ thống" "$TQ"

  BD=$(( $(date +%s) - 1800 ))
  KT=$(date +%s)
  QID=$(aws logs start-query --log-group-name "$LG" \
    --start-time "$BD" --end-time "$KT" --query-string "$CAU" --limit 20 \
    --query queryId --output text 2>/dev/null)

  if [ -z "$QID" ] || [ "$QID" = "None" ]; then
    fail "truy vấn chạy được trên nhóm nhật ký của lab" \
      "start-query chấp nhận câu truy vấn" \
      "AWS từ chối câu truy vấn — cú pháp Logs Insights sai, hoặc nó tham chiếu trường không tồn tại"
  else
    printf '    chờ truy vấn chạy xong '
    KQ=""
    TROI=0
    while [ "$TROI" -lt 90 ]; do
      KQ=$(aws logs get-query-results --query-id "$QID" --output json 2>/dev/null)
      TT_Q=$(printf '%s' "$KQ" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("status",""))' 2>/dev/null)
      [ "$TT_Q" = "Complete" ] && break
      sleep 5
      TROI=$((TROI + 5))
      printf '.'
    done
    printf ' [%ds]\n' "$TROI"

    read -r SO_DONG_KQ MS_DAU < <(printf '%s' "$KQ" | python3 -c '
import sys, json
try:
    d = json.load(sys.stdin)
except Exception:
    print("0 -"); raise SystemExit
rows = d.get("results") or []
def lay(r, ten):
    for c in r:
        if c.get("field") == ten:
            return c.get("value") or "-"
    return "-"
print(len(rows), lay(rows[0], "ms") if rows else "-")
' 2>/dev/null)

    if [ "${SO_DONG_KQ:-0}" -ge 1 ] 2>/dev/null; then
      ok "truy vấn trả về được kết quả" "$SO_DONG_KQ dòng"
    else
      fail "truy vấn trả về được kết quả" ">= 1 dòng trong 30 phút qua" \
        "0 dòng — truy vấn chạy nhưng không khớp gì; kiểm tra tên trường trong nhật ký JSON"
    fi

    if [ "${MS_DAU:--}" != "-" ] && [ "${MS_DAU%%.*}" -ge 1000 ] 2>/dev/null; then
      ok "dòng đầu tiên đúng là yêu cầu chậm nhất" "ms = $MS_DAU"
    else
      fail "dòng đầu tiên đúng là yêu cầu chậm nhất" \
        "cột ms ở dòng đầu >= 1000 (verify vừa tạo hai yêu cầu 1500ms và 2500ms)" \
        "ms = ${MS_DAU:--} — truy vấn thiếu cột tên ms, hoặc chưa sort ms desc"
    fi
  fi
fi

# ---------------------------------------------------------------------------
section "7. State nằm ở nơi cả đội dùng được (yêu cầu 7)"
# ---------------------------------------------------------------------------

assert_cmd_ok "state Terraform thật sự nằm trong kho dùng chung" \
  aws s3api head-object --bucket "$KHO" --key "$DUONG"

VER=$(aws s3api get-bucket-versioning --bucket "$KHO" --query 'Status' --output text 2>/dev/null)
assert_eq "kho state giữ lịch sử phiên bản" "Enabled" "${VER:-<chưa bật>}"

MAHOA=$(aws s3api get-bucket-encryption --bucket "$KHO" \
  --query 'ServerSideEncryptionConfiguration.Rules[0].ApplyServerSideEncryptionByDefault.SSEAlgorithm' \
  --output text 2>/dev/null)
case "${MAHOA:-}" in
AES256 | aws:kms) ok "state được mã hoá khi nằm yên" "$MAHOA" ;;
*) fail "state được mã hoá khi nằm yên" "AES256 hoặc aws:kms" "${MAHOA:-<không đọc được>}" ;;
esac

CHAN=$(aws s3api get-public-access-block --bucket "$KHO" \
  --query 'join(`,`,[to_string(PublicAccessBlockConfiguration.BlockPublicAcls),to_string(PublicAccessBlockConfiguration.IgnorePublicAcls),to_string(PublicAccessBlockConfiguration.BlockPublicPolicy),to_string(PublicAccessBlockConfiguration.RestrictPublicBuckets)])' \
  --output text 2>/dev/null)
assert_eq "kho state chặn public đủ bốn công tắc" "true,true,true,true" "${CHAN:-<chưa đặt>}"

# NEGATIVE — người ngoài không đọc được state. State chứa mọi thứ, kể cả bí mật.
assert_cmd_fail "người KHÔNG có credential không đọc được state" \
  aws s3api get-object --no-sign-request --bucket "$KHO" --key "$DUONG" /dev/null

KHOA=$(aws dynamodb describe-table --table-name "$BANG" \
  --query 'Table.KeySchema[?KeyType==`HASH`].AttributeName | [0]' --output text 2>/dev/null)
assert_eq "bảng khoá có đúng khoá chính mà Terraform cần" "LockID" "${KHOA:-<không tìm thấy bảng>}"

TT_BANG=$(aws dynamodb describe-table --table-name "$BANG" \
  --query 'Table.BillingModeSummary.BillingMode' --output text 2>/dev/null)
assert_eq "bảng khoá tính tiền theo lượt dùng, không đặt trước dung lượng" \
  "PAY_PER_REQUEST" "${TT_BANG:-PROVISIONED}"

# ---------------------------------------------------------------------------
section "8. PHỦ ĐỊNH — không gì trong lab này tính tiền theo giờ (yêu cầu 8)"
# ---------------------------------------------------------------------------

SO_MAY=$(aws ec2 describe-instances \
  --filters "Name=tag:lab,Values=w10" "Name=instance-state-name,Values=pending,running,stopping,stopped" \
  --query 'length(Reservations[].Instances[])' --output text 2>/dev/null)
assert_eq "không có máy chủ nào mang tag lab=w10" "0" "${SO_MAY:-0}"

SO_DAT=$(aws resourcegroupstaggingapi get-resources \
  --tag-filters "Key=lab,Values=w10" \
  --resource-type-filters elasticloadbalancing rds elasticache \
  --query 'length(ResourceTagMappingList)' --output text 2>/dev/null)
assert_eq "không có cân bằng tải / cơ sở dữ liệu / cache nào mang tag lab=w10" "0" "${SO_DAT:-0}"

# ---------------------------------------------------------------------------
if summary; then
  cat <<'EOF'

Hai câu tự hỏi trước khi đọc DOI-CHIEU.md:

  1. Cảnh báo của bạn vừa kêu vì SỐ LỖI vượt ngưỡng. Nếu lưu lượng tăng 100 lần
     thì 3 lỗi mỗi phút là chuyện bình thường, và cảnh báo sẽ kêu suốt ngày.
     Đo bằng TỈ LỆ lỗi thay vì số lỗi thì cần gì mà bây giờ bạn chưa có?
     (Gợi ý: một phép chia cần hai số đo, và CloudWatch có một cơ chế cho việc đó.)

  2. Hàm của bạn ghi log rồi metric filter đếm log. Nếu hàm chết trước khi kịp
     ghi dòng nào — hết bộ nhớ, timeout — thì số đo lỗi của bạn có tăng không?
     Cái gì đang giám sát loại lỗi ĐÓ, và nó khác gì loại lỗi bạn vừa đo?
EOF
fi
