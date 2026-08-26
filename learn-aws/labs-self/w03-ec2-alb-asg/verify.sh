#!/usr/bin/env bash
# Trọng tài của lab tuần 3.
#
# CẢNH BÁO: script này THẬT SỰ TERMINATE một máy đang phục vụ, rồi vừa gọi liên
# tục vào endpoint của bạn vừa chờ hệ thống tự dựng lại. Đó là điểm của lab.
# Nó không xoá gì khác và không sửa cấu hình nào — nhóm quản lý đàn máy của bạn
# sẽ tự đưa mọi thứ về trạng thái cũ.
#
# Bỏ qua phần đó khi đang debug:   SKIP_CHAOS=1 ./verify.sh
set -uo pipefail
cd "$(dirname "$0")" || exit 1
source ../_lib/check.sh

export AWS_PROFILE="${LAB_PROFILE:-lab-builder}"
export AWS_REGION="us-east-1"
export AWS_DEFAULT_REGION="us-east-1"

check_init "Tuần 3 — Giết một máy, không ai biết: ALB + ASG + tự phục hồi"

URL=$(need_output endpoint_url)      || exit 1
ASG=$(need_output asg_name)          || exit 1
TG=$(need_output target_group_arn)   || exit 1
VPC=$(need_output vpc_id)            || exit 1
CHI_PHI=$(need_output chi_phi)       || exit 1

echo
echo "  chi_phi = $CHI_PHI"

# --- tiện ích ---------------------------------------------------------------

goi() {   # goi -> "<ma-http>|<than-response-rut-gon>"
  local r
  r=$(curl -s -m 8 -w '|%{http_code}' "$URL" 2>/dev/null)
  printf '%s|%s' "${r##*|}" "$(printf '%s' "${r%|*}" | tr -d '\n' | head -c 200)"
}

may_dang_phuc_vu() {
  aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names "$ASG" \
    --query 'AutoScalingGroups[0].Instances[?LifecycleState==`InService`].InstanceId' \
    --output text 2>/dev/null | tr -s '[:space:]' '\n' | grep -v '^$' | sort
}

so_may_khoe() {
  aws elbv2 describe-target-health --target-group-arn "$TG" \
    --query "length(TargetHealthDescriptions[?TargetHealth.State=='healthy'])" \
    --output text 2>/dev/null
}

con_trong_target_group() {   # <instance-id> -> 0 nếu còn
  aws elbv2 describe-target-health --target-group-arn "$TG" \
    --query 'TargetHealthDescriptions[].Target.Id' --output text 2>/dev/null \
    | tr -s '[:space:]' '\n' | grep -qx "$1"
}

# ---------------------------------------------------------------------------
section "Endpoint công khai (yêu cầu 1, 2)"

assert_contains "endpoint_url có scheme http" "http" "$URL"

KQ=$(goi); MA="${KQ%%|*}"; THAN="${KQ#*|}"
assert_eq "gọi vào endpoint trả về 200" "200" "$MA"
DINH_DANH=$(printf '%s' "$THAN" | grep -o 'i-[0-9a-f]\{8,\}' | head -1)
if [ -n "$DINH_DANH" ]; then
  ok "response cho biết máy nào đang phục vụ" "$DINH_DANH"
else
  fail "response cho biết máy nào đang phục vụ" "thân response chứa i-xxxxxxxx" "${THAN:0:80}"
fi

# ---------------------------------------------------------------------------
section "Quy mô và phân bố (yêu cầu 3, 4, 8)"

read -r DESIRED MINSIZE MAXSIZE HCTYPE < <(
  aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names "$ASG" \
    --query 'AutoScalingGroups[0].[DesiredCapacity,MinSize,MaxSize,HealthCheckType]' \
    --output text 2>/dev/null)

SO_AZ_ASG=$(aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names "$ASG" \
  --query 'AutoScalingGroups[0].AvailabilityZones' --output text 2>/dev/null \
  | tr -s '[:space:]' '\n' | sort -u | grep -c '.')

if [ "${DESIRED:-0}" -ge 2 ] 2>/dev/null; then
  ok "nhóm máy đặt mục tiêu ít nhất 2 máy" "desired=$DESIRED min=$MINSIZE max=$MAXSIZE"
else
  fail "nhóm máy đặt mục tiêu ít nhất 2 máy" ">= 2" "desired=${DESIRED:-khong-doc-duoc}"
fi

if [ "${MAXSIZE:-99}" -le 4 ] 2>/dev/null; then
  ok "trần quy mô nằm trong hàng rào chi phí" "max=$MAXSIZE (<= 4)"
else
  fail "trần quy mô nằm trong hàng rào chi phí" "<= 4" "max=${MAXSIZE:-?}"
fi

if [ "${SO_AZ_ASG:-0}" -ge 2 ]; then
  ok "nhóm máy trải trên ít nhất 2 vùng sẵn sàng" "$SO_AZ_ASG AZ"
else
  fail "nhóm máy trải trên ít nhất 2 vùng sẵn sàng" ">= 2 AZ" "${SO_AZ_ASG:-0} AZ"
fi

KHOE=$(so_may_khoe)
if [ "${KHOE:-0}" -ge 2 ] 2>/dev/null; then
  ok "có ít nhất 2 máy đang ở trạng thái khoẻ" "$KHOE máy healthy"
else
  fail "có ít nhất 2 máy đang ở trạng thái khoẻ" ">= 2" "${KHOE:-0} máy healthy"
fi

DS_MAY=""
for _ in $(seq 1 20); do
  K=$(goi)
  DS_MAY="$DS_MAY$(printf '%s' "${K#*|}" | grep -o 'i-[0-9a-f]\{8,\}' | head -1)
"
done
SO_MAY_KHAC=$(printf '%s' "$DS_MAY" | grep -v '^$' | sort -u | grep -c '.')
if [ "${SO_MAY_KHAC:-0}" -ge 2 ]; then
  ok "20 request được chia cho nhiều máy" "$SO_MAY_KHAC máy khác nhau trả lời"
else
  fail "20 request được chia cho nhiều máy" ">= 2 máy khác nhau" "${SO_MAY_KHAC:-0}"
fi

# ---------------------------------------------------------------------------
section "PHỦ ĐỊNH — máy phục vụ không lộ ra internet (yêu cầu 5)"

DS_INST=$(may_dang_phuc_vu | tr '\n' ' ')
if [ -z "${DS_INST// /}" ]; then
  fail "đọc được danh sách máy đang phục vụ" "ít nhất 1 máy" "không có máy nào InService"
else
  SO_IP_CONG_KHAI=0
  for I in $DS_INST; do
    P=$(aws ec2 describe-instances --instance-ids "$I" \
          --query 'Reservations[0].Instances[0].PublicIpAddress' --output text 2>/dev/null)
    if [ "$P" != "None" ] && [ -n "$P" ]; then
      SO_IP_CONG_KHAI=$((SO_IP_CONG_KHAI+1))
      if timeout 8 bash -c "</dev/tcp/$P/80" 2>/dev/null; then
        fail "máy $I không nhận kết nối trực tiếp từ internet" "không kết nối được" "port 80 MỞ trên $P"
      fi
    fi
  done
  assert_eq "không máy phục vụ nào có địa chỉ IP công khai" "0" "$SO_IP_CONG_KHAI"

  MOT_MAY=${DS_INST%% *}
  SGS=$(aws ec2 describe-instances --instance-ids "$MOT_MAY" \
          --query 'Reservations[0].Instances[0].SecurityGroups[].GroupId' --output text 2>/dev/null)
  MO_TOANG=$(aws ec2 describe-security-groups --group-ids $SGS \
      --query 'SecurityGroups[].IpPermissions[].[IpRanges[].CidrIp,Ipv6Ranges[].CidrIpv6]' \
      --output text 2>/dev/null | tr -s '[:space:]' '\n' \
      | grep -c -e '^0\.0\.0\.0/0$' -e '^::/0$')
  assert_eq "security group của máy phục vụ không mở cửa từ cả internet" "0" "${MO_TOANG:-loi}"
fi

# ---------------------------------------------------------------------------
section "Health check hỏi đúng chỗ (yêu cầu 6)"

if [ "${HCTYPE:-}" = "ELB" ]; then
  ok "nhóm máy đánh giá sức khoẻ bằng kết luận của load balancer" "HealthCheckType=ELB"
else
  fail "nhóm máy đánh giá sức khoẻ bằng kết luận của load balancer" \
       "ELB" "${HCTYPE:-khong-doc-duoc} — kiểu này chỉ nhìn phần cứng EC2, tiến trình web chết vẫn coi là khoẻ"
fi

read -r HC_INTERVAL HC_NGUONG HC_DUONG_DAN < <(
  aws elbv2 describe-target-groups --target-group-arns "$TG" \
    --query 'TargetGroups[0].[HealthCheckIntervalSeconds,UnhealthyThresholdCount,HealthCheckPath]' \
    --output text 2>/dev/null)
ok "cấu hình health check của load balancer" \
   "mỗi ${HC_INTERVAL}s, hỏng sau ${HC_NGUONG} lần fail, đường dẫn ${HC_DUONG_DAN}"

# ---------------------------------------------------------------------------
section "Tự phục hồi — bài kiểm tra chính (yêu cầu 7)"

if [ "${SKIP_CHAOS:-0}" = "1" ]; then
  echo "  (bỏ qua theo SKIP_CHAOS=1 — lab chỉ tính là xong khi đã chạy đủ ít nhất một lần)"
  summary
  exit 0
fi

TRUOC=$(may_dang_phuc_vu)
NAN_NHAN=$(printf '%s' "$TRUOC" | head -1)

if [ -z "$NAN_NHAN" ]; then
  fail "chọn được một máy để terminate" "một instance InService" "không có máy nào"
  summary
  exit 1
fi

echo
echo "  Sắp terminate $NAN_NHAN. Từ giây này, mỗi 2 giây một request đi vào"
echo "  endpoint của bạn, và mọi mã trả về khác 200 đều được đếm."
echo

aws ec2 terminate-instances --instance-ids "$NAN_NHAN" >/dev/null 2>&1 || {
  fail "terminate được máy" "thành công" "gọi API thất bại — kiểm tra quyền của lab-builder"
  summary; exit 1; }

BAT_DAU=$(date +%s)
TONG=0; LOI=0; LOI_DAU=0; LOI_CUOI=0
MAY_MOI=""; DA_GO_KHOI_TG=0
GIOI_HAN=$((12*60))

while :; do
  TROI=$(( $(date +%s) - BAT_DAU ))
  [ "$TROI" -ge "$GIOI_HAN" ] && break

  K=$(goi); MA="${K%%|*}"
  TONG=$((TONG+1))
  if [ "$MA" != "200" ]; then
    LOI=$((LOI+1))
    [ "$LOI_DAU" -eq 0 ] && LOI_DAU=$TROI
    LOI_CUOI=$TROI
  fi

  if [ "$DA_GO_KHOI_TG" -eq 0 ] && ! con_trong_target_group "$NAN_NHAN"; then
    DA_GO_KHOI_TG=$TROI
    [ "$DA_GO_KHOI_TG" -eq 0 ] && DA_GO_KHOI_TG=1
  fi

  if [ $((TONG % 5)) -eq 0 ]; then
    HIEN_TAI=$(may_dang_phuc_vu)
    MAY_MOI=$(comm -13 <(printf '%s\n' "$TRUOC") <(printf '%s\n' "$HIEN_TAI") | head -1)
    KHOE=$(so_may_khoe)
    printf '\r  %3ds  |  request %3d  lỗi %3d  |  máy khoẻ %s  |  máy mới: %s        ' \
      "$TROI" "$TONG" "$LOI" "${KHOE:-?}" "${MAY_MOI:-chưa có}"
    if [ -n "$MAY_MOI" ] && [ "${KHOE:-0}" -ge 2 ] 2>/dev/null && [ "$DA_GO_KHOI_TG" -ne 0 ]; then
      sleep 10
      break
    fi
  fi
  sleep 2
done
echo; echo

TONG_TROI=$(( $(date +%s) - BAT_DAU ))

if [ -n "$MAY_MOI" ]; then
  ok "nhóm máy tự dựng một máy MỚI thay thế" "$NAN_NHAN chết -> $MAY_MOI thay vào (sau ~${TONG_TROI}s)"
else
  fail "nhóm máy tự dựng một máy MỚI thay thế" "một instance id chưa từng thấy, trong 12 phút" \
       "không có máy mới nào vào InService"
fi

if [ "$DA_GO_KHOI_TG" -ne 0 ]; then
  ok "PHỦ ĐỊNH: máy đã chết bị gỡ khỏi vòng nhận traffic" "gỡ ra sau ~${DA_GO_KHOI_TG}s"
else
  fail "PHỦ ĐỊNH: máy đã chết bị gỡ khỏi vòng nhận traffic" \
       "$NAN_NHAN biến mất khỏi target group" "vẫn còn trong target group sau ${TONG_TROI}s"
fi

if [ "$TONG" -gt 0 ]; then
  TI_LE=$(( LOI * 100 / TONG ))
  CUA_SO=$(( LOI_CUOI - LOI_DAU ))
  [ "$LOI" -eq 0 ] && CUA_SO=0
  echo "  Thời gian suy giảm: ${CUA_SO}s  (lỗi đầu ở giây $LOI_DAU, lỗi cuối ở giây $LOI_CUOI)"
  echo "  Ghi con số này lại — Tiêu chí đạt yêu cầu bạn giải thích nó."
  echo
  if [ "$TI_LE" -lt 15 ]; then
    ok "tỉ lệ request lỗi trong lúc phục hồi dưới 15%" "$LOI/$TONG = ${TI_LE}%"
  else
    fail "tỉ lệ request lỗi trong lúc phục hồi dưới 15%" "< 15%" "$LOI/$TONG = ${TI_LE}%"
  fi
fi

LOI_SAU=0
for _ in $(seq 1 10); do
  K=$(goi); [ "${K%%|*}" != "200" ] && LOI_SAU=$((LOI_SAU+1))
  sleep 1
done
assert_eq "sau khi phục hồi, 10 request liên tiếp đều thành công" "0" "$LOI_SAU"

KHOE_CUOI=$(so_may_khoe)
if [ "${KHOE_CUOI:-0}" -ge 2 ] 2>/dev/null; then
  ok "số máy khoẻ trở lại như trước sự cố" "$KHOE_CUOI máy healthy"
else
  fail "số máy khoẻ trở lại như trước sự cố" ">= 2" "${KHOE_CUOI:-0}"
fi

summary

cat <<'EOF'

Hai câu tự hỏi trước khi mở DOI-CHIEU.md:

  1. Tỉ lệ lỗi của bạn không phải 0%. Cửa sổ suy giảm đó dài đúng bằng tổng của
     ba con số nào trong cấu hình? Giảm chúng xuống thì được gì và mất gì?
     (Gợi ý cho vế "mất gì": health check quá nhạy trên một ứng dụng thỉnh
     thoảng chậm sẽ sinh ra chuyện gì?)

  2. Hệ thống vừa chịu được MỘT MÁY chết. Bây giờ tưởng tượng cả một vùng sẵn
     sàng mất điện. Với desired capacity hiện tại của bạn, còn bao nhiêu máy
     phục vụ? Đủ tải không? Con số desired nào mới thật sự chịu được một AZ chết?
EOF
