#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")/terraform"

PROFILE="${AWS_PROFILE:-learn}"
REGION="${AWS_REGION:-us-east-1}"
TABLE=$(terraform output -raw table_name 2>/dev/null) || {
  echo "Chưa apply. Chạy: cd terraform && terraform apply"; exit 1; }

aws() { command aws --profile "$PROFILE" --region "$REGION" "$@"; }
pass=0; fail=0
ok()  { printf '  \033[32m✓\033[0m %s\n' "$1"; pass=$((pass+1)); }
bad() { printf '  \033[31m✗\033[0m %s\n' "$1"; fail=$((fail+1)); }

echo
echo "1. Cấu hình bảng DynamoDB"
aws dynamodb describe-table --table-name "$TABLE" \
  --query 'Table.{Ten:TableName,Items:ItemCount,Mode:BillingModeSummary.BillingMode,Stream:StreamSpecification.StreamViewType,Size:TableSizeBytes}' \
  --output table

echo "2. TTL"
TTL=$(aws dynamodb describe-time-to-live --table-name "$TABLE" \
       --query 'TimeToLiveDescription.TimeToLiveStatus' --output text)
[ "$TTL" = "ENABLED" ] && ok "TTL bật (miễn phí, không tốn write capacity)" || bad "TTL = $TTL"

echo
echo "3. GSI"
aws dynamodb describe-table --table-name "$TABLE" \
  --query 'Table.GlobalSecondaryIndexes[].{Ten:IndexName,TrangThai:IndexStatus,Projection:Projection.ProjectionType,Items:ItemCount}' \
  --output table

echo "4. Point-in-time recovery (nên TẮT trong lab — tốn ~\$0,20/GB/tháng)"
PITR=$(aws dynamodb describe-continuous-backups --table-name "$TABLE" \
        --query 'ContinuousBackupsDescription.PointInTimeRecoveryDescription.PointInTimeRecoveryStatus' --output text 2>/dev/null)
[ "$PITR" = "DISABLED" ] && ok "PITR tắt — đúng cho lab" || printf '  \033[33m◐\033[0m PITR = %s (tốn tiền)\n' "$PITR"

echo
echo "5. Lambda tiêu thụ stream"
FN=$(terraform output -raw stream_lambda_name)
ESM=$(aws lambda list-event-source-mappings --function-name "$FN" \
       --query 'EventSourceMappings[0].State' --output text 2>/dev/null)
[ "$ESM" = "Enabled" ] && ok "event source mapping Enabled" || bad "mapping = $ESM"

echo
echo "6. Log retention (mặc định của Lambda là VĨNH VIỄN)"
LG=$(terraform output -raw stream_log_group)
RET=$(aws logs describe-log-groups --log-group-name-prefix "$LG" \
       --query 'logGroups[0].retentionInDays' --output text 2>/dev/null)
[ "$RET" != "None" ] && [ -n "$RET" ] && ok "retention $RET ngày" \
  || bad "retention = vĩnh viễn — sẽ ăn hết 5 GB miễn phí"

echo
echo "7. RDS — thứ tốn tiền duy nhất của tuần này"
RDS=$(aws rds describe-db-instances \
       --query 'DBInstances[].[DBInstanceIdentifier,DBInstanceClass,DBInstanceStatus,MultiAZ]' \
       --output text 2>/dev/null)
if [ -z "$RDS" ]; then
  ok "không có RDS instance nào đang chạy"
else
  printf '  \033[33m◐\033[0m RDS ĐANG CHẠY:\n'
  printf '%s\n' "$RDS" | sed 's/^/      /'
  printf '      ~$0,016/giờ + storage. ĐÃ ĐẶT HẸN GIỜ CHƯA?\n'
  printf '      Xoá: terraform apply -var enable_rds=false\n'
fi

echo
echo "8. Snapshot RDS bị bỏ quên (tính tiền theo dung lượng)"
SNAP=$(aws rds describe-db-snapshots --snapshot-type manual \
        --query 'DBSnapshots[].[DBSnapshotIdentifier,AllocatedStorage]' --output text 2>/dev/null)
[ -z "$SNAP" ] && ok "không có snapshot thủ công nào" \
  || { printf '  \033[33m◐\033[0m còn snapshot:\n'; printf '%s\n' "$SNAP" | sed 's/^/      /'; }

echo
printf 'Đạt: %d   Hỏng: %d\n' "$pass" "$fail"
terraform output -raw chi_phi; echo
cat <<'EOF'

Câu hỏi tự trả lời:

  1. Bạn vừa đo Scan tốn gấp bao nhiêu lần Query. FilterExpression có làm
     giảm lượng dữ liệu ĐỌC không, hay chỉ giảm lượng TRẢ VỀ?

  2. Vì sao đơn hàng dùng chung partition key với khách hàng, thay vì có
     bảng riêng như trong SQL?

  3. Multi-AZ và Read Replica — cái nào giúp chịu lỗi, cái nào giúp mở rộng
     đọc? Standby của Multi-AZ có phục vụ đọc không?

  4. GSI và LSI khác nhau ở ba điểm nào? Cái nào KHÔNG thêm được sau khi
     bảng đã tạo?
EOF
