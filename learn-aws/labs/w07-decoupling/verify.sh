#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")/terraform"
PROFILE="${AWS_PROFILE:-learn}"; REGION="${AWS_REGION:-us-east-1}"
Q1=$(terraform output -raw queue_don_hang_url 2>/dev/null) || { echo "Chưa apply."; exit 1; }
Q2=$(terraform output -raw queue_kho_hang_url); DLQ=$(terraform output -raw dlq_url)
aws() { command aws --profile "$PROFILE" --region "$REGION" "$@"; }

dem() { aws sqs get-queue-attributes --queue-url "$1" \
  --attribute-names ApproximateNumberOfMessages ApproximateNumberOfMessagesNotVisible \
  --query 'Attributes.[ApproximateNumberOfMessages,ApproximateNumberOfMessagesNotVisible]' --output text; }

echo
echo "════ Hàng đợi ════"
printf '  %-34s %s\n' "hàng đợi" "chờ / đang xử lý"
printf '  %-34s %s\n' "don-hang"     "$(dem "$Q1")"
printf '  %-34s %s\n' "kho-hang"     "$(dem "$Q2")"
printf '  %-34s %s\n' "don-hang-DLQ" "$(dem "$DLQ")"

echo
echo "════ Filter policy trên mỗi subscription ════"
aws sns list-subscriptions-by-topic --topic-arn "$(terraform output -raw sns_topic_arn)" \
  --query 'Subscriptions[].SubscriptionArn' --output text | tr '\t' '\n' | while read -r s; do
  [ -z "$s" ] || [ "$s" = "PendingConfirmation" ] && continue
  EP=$(aws sns get-subscription-attributes --subscription-arn "$s" \
        --query 'Attributes.Endpoint' --output text | awk -F: '{print $NF}')
  FP=$(aws sns get-subscription-attributes --subscription-arn "$s" \
        --query 'Attributes.FilterPolicy' --output text)
  printf '  %-24s %s\n' "$EP" "$FP"
done

echo
echo "════ EventBridge rule ════"
aws events list-rules --name-prefix "$(terraform output -raw lich_dang_bat >/dev/null 2>&1; echo w07)" \
  --query 'Rules[].[Name,State,ScheduleExpression]' --output table 2>/dev/null

STATE=$(aws events list-rules --name-prefix w07 --query 'Rules[0].State' --output text 2>/dev/null)
if [ "$STATE" = "ENABLED" ]; then
  printf '  \033[33m◐\033[0m Rule ĐANG CHẠY — sinh log mỗi 5 phút.\n'
  printf '     Tắt: terraform apply -var bat_lich=false\n'
else
  printf '  \033[32m✓\033[0m Rule đang tắt (đúng)\n'
fi

echo
echo "════ Step Functions — 5 lần chạy gần nhất ════"
aws stepfunctions list-executions --state-machine-arn "$(terraform output -raw state_machine_arn)" \
  --max-items 5 --query 'executions[].[name,status,startDate]' --output table 2>/dev/null

echo
cat <<'EOF'
Câu hỏi tự trả lời:

  1. Lambda timeout 10s, visibility timeout 60s. Nếu đảo ngược (visibility 5s)
     thì chuyện gì xảy ra với mỗi message?

  2. Producer publish vào SNS mà không biết có bao nhiêu SQS đang nghe.
     Muốn thêm một consumer thứ ba, bạn phải sửa gì ở phía producer?

  3. SQS Standard vs FIFO: cái nào đảm bảo thứ tự, cái nào có throughput cao hơn?
     FIFO cần thêm tham số gì khi gửi message?

  4. Khi nào chọn SQS, khi nào chọn Kinesis Data Streams? (Gợi ý: nhiều consumer
     độc lập đọc CÙNG dữ liệu, và khả năng tua lại.)
EOF
