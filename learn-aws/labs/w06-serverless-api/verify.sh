#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")/terraform"

PROFILE="${AWS_PROFILE:-learn}"
REGION="${AWS_REGION:-us-east-1}"
API=$(terraform output -raw api_url 2>/dev/null) || {
  echo "Chưa apply. Chạy: cd terraform && terraform apply"; exit 1; }
FN=$(terraform output -raw lambda_name)
LG=$(terraform output -raw lambda_log_group)

aws() { command aws --profile "$PROFILE" --region "$REGION" "$@"; }
pass=0; fail=0
ok()  { printf '  \033[32m✓\033[0m %s\n' "$1"; pass=$((pass+1)); }
bad() { printf '  \033[31m✗\033[0m %s\n' "$1"; fail=$((fail+1)); }

echo
echo "1. API sống"
CODE=$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 "$API/health")
[ "$CODE" = "200" ] && ok "GET /health → 200" || bad "GET /health → $CODE"

echo
echo "2. CRUD end-to-end"
ID=$(curl -s -X POST "$API/ghichu" -H 'content-type: application/json' \
      -H 'x-nguoi-dung: verify' -d '{"noi_dung":"test tu verify.sh"}' \
      | grep -o '"id": *"[^"]*"' | cut -d'"' -f4)
[ -n "$ID" ] && ok "POST tạo được ghi chú id=$ID" || bad "POST thất bại"

if [ -n "$ID" ]; then
  G=$(curl -s -o /dev/null -w '%{http_code}' "$API/ghichu/$ID" -H 'x-nguoi-dung: verify')
  [ "$G" = "200" ] && ok "GET đọc lại được" || bad "GET → $G"
  D=$(curl -s -o /dev/null -w '%{http_code}' -X DELETE "$API/ghichu/$ID" -H 'x-nguoi-dung: verify')
  [ "$D" = "204" ] && ok "DELETE → 204" || bad "DELETE → $D"
fi

echo
echo "3. Cách ly dữ liệu giữa người dùng"
N=$(curl -s "$API/ghichu" -H 'x-nguoi-dung: nguoi-la-hoan-toan' | grep -o '"so_luong": *[0-9]*' | grep -o '[0-9]*$')
[ "${N:-x}" = "0" ] && ok "người dùng lạ thấy 0 ghi chú (partition key cách ly đúng)" \
  || bad "người dùng lạ thấy $N ghi chú — rò rỉ dữ liệu!"

echo
echo "4. Cấu hình Lambda"
aws lambda get-function-configuration --function-name "$FN" \
  --query '{Runtime:Runtime,Memory:MemorySize,Timeout:Timeout,Tracing:TracingConfig.Mode,VPC:VpcConfig.VpcId}' \
  --output table

VPCID=$(aws lambda get-function-configuration --function-name "$FN" --query 'VpcConfig.VpcId' --output text)
[ "$VPCID" = "None" ] || [ -z "$VPCID" ] && ok "Lambda KHÔNG trong VPC (đúng — DynamoDB là API công khai)" \
  || bad "Lambda đang trong VPC $VPCID — cần NAT hoặc endpoint, tốn tiền"

echo
echo "5. Log retention (mặc định Lambda là VĨNH VIỄN)"
for g in "$LG" "$(terraform output -raw access_log_group)"; do
  R=$(aws logs describe-log-groups --log-group-name-prefix "$g" \
       --query 'logGroups[0].retentionInDays' --output text 2>/dev/null)
  [ "$R" != "None" ] && [ -n "$R" ] && ok "$g → $R ngày" || bad "$g → vĩnh viễn"
done

echo
echo "6. Throttling đã đặt"
aws apigatewayv2 get-stage --api-id "$(basename "$API" | cut -d. -f1)" --stage-name '$default' \
  --query 'DefaultRouteSettings.{Rate:ThrottlingRateLimit,Burst:ThrottlingBurstLimit}' \
  --output table 2>/dev/null || echo "  (không đọc được, kiểm tra bằng console)"

echo
echo "7. Quyền IAM tối thiểu"
ROLE=$(aws lambda get-function-configuration --function-name "$FN" --query 'Role' --output text | awk -F/ '{print $NF}')
POL=$(aws iam list-role-policies --role-name "$ROLE" --query 'PolicyNames[0]' --output text)
ACTIONS=$(aws iam get-role-policy --role-name "$ROLE" --policy-name "$POL" \
           --query 'PolicyDocument.Statement[0].Action' --output text 2>/dev/null)
echo "  Action được cấp: $ACTIONS"
echo "$ACTIONS" | grep -q 'Scan' && bad "có quyền Scan — nên bỏ, Scan đọc cả bảng" \
  || ok "không có dynamodb:Scan (least privilege)"

echo
printf 'Đạt: %d   Hỏng: %d\n' "$pass" "$fail"
cat <<'EOF'

Câu hỏi tự trả lời:

  1. Trong handler.py, dòng `TABLE = boto3.resource(...)` nằm NGOÀI hàm handler.
     Nếu chuyển vào trong thì chuyện gì xảy ra với mỗi request?

  2. Lambda cần đọc DynamoDB. Có cần đặt Lambda vào VPC không? Vì sao?

  3. HTTP API rẻ hơn REST API ~70%. Vậy khi nào vẫn phải chọn REST API?

  4. Nếu thiếu aws_lambda_permission, API trả 500 và log Lambda TRỐNG TRƠN.
     Vì sao log trống lại là manh mối quan trọng?
EOF
