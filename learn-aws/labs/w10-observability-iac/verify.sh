#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")/terraform"
PROFILE="${AWS_PROFILE:-learn}"; REGION="${AWS_REGION:-us-east-1}"
TOPIC=$(terraform output -raw sns_topic_arn 2>/dev/null) || { echo "Chưa apply."; exit 1; }
aws() { command aws --profile "$PROFILE" --region "$REGION" "$@"; }

echo
echo "════ 1. Đăng ký email — điều kiện tiên quyết ════"
SUB=$(aws sns list-subscriptions-by-topic --topic-arn "$TOPIC" \
       --query 'Subscriptions[].[Protocol,Endpoint,SubscriptionArn]' --output text 2>/dev/null)
if [ -z "$SUB" ]; then
  printf '  \033[31m✗\033[0m chưa có subscription. Chạy:\n'
  printf '     terraform apply -var email_canh_bao=ban@example.com\n'
elif echo "$SUB" | grep -q PendingConfirmation; then
  printf '  \033[31m✗\033[0m CHƯA XÁC NHẬN — vào hộp thư bấm "Confirm subscription"\n'
  printf '%s\n' "$SUB" | sed 's/^/      /'
else
  printf '  \033[32m✓\033[0m email đã xác nhận\n'
  printf '%s\n' "$SUB" | sed 's/^/      /'
fi

echo
echo "════ 2. Trạng thái alarm ════"
aws cloudwatch describe-alarms \
  --alarm-names "$(terraform output -raw alarm_loi)" "$(terraform output -raw alarm_cham)" \
  --query 'MetricAlarms[].[AlarmName,StateValue,StateUpdatedTimestamp]' --output table

aws cloudwatch describe-alarms --alarm-types CompositeAlarm \
  --query 'CompositeAlarms[].[AlarmName,StateValue]' --output table 2>/dev/null

echo "════ 3. treat_missing_data — tham số hay bị hiểu sai nhất ════"
for a in "$(terraform output -raw alarm_loi)" "$(terraform output -raw alarm_cham)"; do
  TMD=$(aws cloudwatch describe-alarms --alarm-names "$a" \
         --query 'MetricAlarms[0].TreatMissingData' --output text)
  if [ "$TMD" = "notBreaching" ]; then
    printf '  \033[32m✓\033[0m %-28s %s\n' "$a" "$TMD"
  else
    printf '  \033[31m✗\033[0m %-28s %s ← alarm sẽ kẹt ở ALARM mãi\n' "$a" "$TMD"
  fi
done
echo "     Lambda KHÔNG gửi metric Errors=0 khi không có lỗi. Để 'missing' thì"
echo "     sau lần lỗi đầu tiên alarm không bao giờ trở về OK được."

echo
echo "════ 4. Metric filter ════"
aws logs describe-metric-filters --log-group-name "$(terraform output -raw log_group)" \
  --query 'metricFilters[].[filterName,metricTransformations[0].metricName,metricTransformations[0].defaultValue]' \
  --output table 2>/dev/null
echo "     defaultValue phải là 0.0 — không có nó, metric chỉ xuất hiện khi CÓ lỗi"
echo "     và alarm rơi lại vào đúng cái bẫy ở mục 3."

echo
echo "════ 5. Log retention ════"
R=$(aws logs describe-log-groups --log-group-name-prefix "$(terraform output -raw log_group)" \
     --query 'logGroups[0].retentionInDays' --output text)
[ "$R" != "None" ] && printf '  \033[32m✓\033[0m %s ngày\n' "$R" || printf '  \033[31m✗\033[0m vĩnh viễn\n'

echo
echo "════ 6. Remote state ════"
B=$(terraform output -raw backend_bucket 2>/dev/null || echo "")
if [ -z "$B" ] || [ "$B" = "null" ]; then
  echo "  Chưa tạo. Bài tập: terraform apply -var tao_backend=true"
else
  printf '  bucket: %s\n' "$B"
  V=$(aws s3api get-bucket-versioning --bucket "$B" --query 'Status' --output text 2>/dev/null)
  [ "$V" = "Enabled" ] && printf '  \033[32m✓\033[0m versioning bật (bắt buộc — cách duy nhất khôi phục state hỏng)\n' \
                       || printf '  \033[31m✗\033[0m versioning = %s\n' "$V"
  printf '  lock table: %s\n' "$(terraform output -raw backend_lock_table)"
fi

echo
echo "Dashboard: $(terraform output -raw dashboard_url)"
echo
cat <<'EOF'
Câu hỏi tự trả lời:

  1. Vì sao alarm dùng p99 chứ không dùng Average? Cho ví dụ số cụ thể.

  2. treat_missing_data có 4 giá trị. Với metric "số lỗi" thì chọn cái nào?
     Với metric "heartbeat báo hệ thống còn sống" thì chọn cái nào?

  3. Composite alarm giải quyết vấn đề gì mà alarm thường không giải quyết được?

  4. Có ba cách tạo custom metric: metric filter từ log, PutMetricData, và
     Embedded Metric Format. Cái nào rẻ nhất khi khối lượng lớn?

  5. Vì sao bucket chứa Terraform state BẮT BUỘC phải bật versioning?
EOF
