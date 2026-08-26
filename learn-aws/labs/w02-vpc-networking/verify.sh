#!/usr/bin/env bash
# Kiểm chứng lab tuần 2 từ BÊN NGOÀI (Ansible kiểm chứng từ bên trong máy).
set -uo pipefail
cd "$(dirname "$0")/terraform"

PROFILE="${AWS_PROFILE:-learn}"
REGION="${AWS_REGION:-us-east-1}"

VPC=$(terraform output -raw vpc_id 2>/dev/null) || {
  echo "Chưa apply. Chạy: cd terraform && terraform apply"; exit 1; }
IID=$(terraform output -raw instance_id)
LOGGRP=$(terraform output -raw flow_log_group 2>/dev/null || echo "")
PORT=$(terraform output -raw blocked_port)

aws() { command aws --profile "$PROFILE" --region "$REGION" "$@"; }
pass=0; fail=0
ok()   { printf '  \033[32m✓\033[0m %s\n' "$1"; pass=$((pass+1)); }
bad()  { printf '  \033[31m✗\033[0m %s\n' "$1"; fail=$((fail+1)); }

echo
echo "1. Instance không có public IP"
PUB=$(aws ec2 describe-instances --instance-ids "$IID" \
        --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
[ "$PUB" = "None" ] && ok "không có public IP (tiết kiệm \$0,005/giờ)" \
                    || bad "có public IP $PUB — lẽ ra không nên"

echo
echo "2. Không có NAT Gateway (kẻ giết credit số 1)"
NAT=$(aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=$VPC" \
        "Name=state,Values=available,pending" --query 'length(NatGateways)' --output text)
[ "$NAT" = "0" ] && ok "không có NAT Gateway (tiết kiệm ~\$33/tháng)" \
                 || bad "$NAT NAT Gateway đang chạy — mỗi cái ~\$33/tháng!"

echo
echo "3. S3 Gateway Endpoint tồn tại và MIỄN PHÍ"
GW=$(aws ec2 describe-vpc-endpoints --filters "Name=vpc-id,Values=$VPC" \
       "Name=vpc-endpoint-type,Values=Gateway" \
       --query 'VpcEndpoints[].ServiceName' --output text)
echo "$GW" | grep -q s3 && ok "Gateway Endpoint cho S3: $GW" \
                        || bad "thiếu S3 Gateway Endpoint"

echo
echo "4. Interface Endpoint — MẤT TIỀN, đếm cho biết"
IF_N=$(aws ec2 describe-vpc-endpoints --filters "Name=vpc-id,Values=$VPC" \
        "Name=vpc-endpoint-type,Values=Interface" --query 'length(VpcEndpoints)' --output text)
printf '  \033[33m◐\033[0m %s interface endpoint đang chạy = ~$%.2f/giờ = ~$%.0f/tháng\n' \
  "$IF_N" "$(echo "$IF_N * 0.01" | bc -l)" "$(echo "$IF_N * 0.01 * 730" | bc -l)"

echo
echo "5. Instance đã đăng ký với SSM (điều kiện để vào máy)"
PING=$(aws ssm describe-instance-information \
        --filters "Key=InstanceIds,Values=$IID" \
        --query 'InstanceInformationList[0].PingStatus' --output text 2>/dev/null)
[ "$PING" = "Online" ] && ok "SSM Agent Online — vào được bằng Session Manager" \
  || bad "SSM chưa thấy máy (PingStatus=$PING). Đợi 1-2 phút sau khi boot, hoặc kiểm tra interface endpoint."

echo
echo "6. IMDSv2 được ép buộc"
TOK=$(aws ec2 describe-instances --instance-ids "$IID" \
       --query 'Reservations[0].Instances[0].MetadataOptions.HttpTokens' --output text)
[ "$TOK" = "required" ] && ok "http_tokens=required (chặn được SSRF lấy credential)" \
                        || bad "http_tokens=$TOK — IMDSv1 đang mở"

echo
echo "7. Flow Logs — tìm gói tin bị NACL chặn"
if [ -n "$LOGGRP" ] && [ "$LOGGRP" != "null" ]; then
  echo "  Log group: $LOGGRP  (log cần 5-10 phút mới xuất hiện)"
  REJ=$(aws logs filter-log-events --log-group-name "$LOGGRP" \
         --filter-pattern "REJECT" --max-items 5 \
         --query 'events[].message' --output text 2>/dev/null | head -5)
  if [ -n "$REJ" ]; then
    ok "tìm thấy bản ghi REJECT:"
    printf '%s\n' "$REJ" | sed 's/^/      /'
  else
    printf '  \033[33m◐\033[0m chưa có REJECT nào. Chạy phần sinh traffic rồi đợi:\n'
    printf '      cd ansible && ansible-playbook site.yml --tags nacl\n'
  fi
else
  printf '  \033[33m◐\033[0m Flow Logs chưa bật (enable_flow_logs = false)\n'
fi

echo
printf 'Đạt: %d   Hỏng: %d\n' "$pass" "$fail"
cat <<EOF

Câu hỏi tự trả lời trước khi destroy:

  1. Public subnet và private subnet trong lab này khác nhau ở ĐÚNG một thứ.
     Thứ đó là gì? (Mở AWS console xem cả hai subnet, tìm điểm khác duy nhất.)

  2. Security Group của máy không có một rule inbound nào, mà bạn vẫn vào được
     máy. Vì sao? Điều đó nói gì về tính chất stateful của SG?

  3. NACL rule 90 chặn port $PORT, rule 100 cho phép tất cả. Nếu đổi rule 90
     thành rule 110 thì chuyện gì xảy ra? Vì sao?

  4. Bạn vừa trả tiền cho $IF_N Interface Endpoint nhưng KHÔNG trả tiền cho
     S3 Gateway Endpoint. Khác biệt kỹ thuật giữa hai loại là gì?

DỌN DẸP NGAY — lab này tốn ~\$0,04/giờ:
  cd terraform && terraform destroy
EOF
