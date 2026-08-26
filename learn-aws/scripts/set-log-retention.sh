#!/usr/bin/env bash
# CloudWatch log group mặc định giữ log VĨNH VIỄN. Với 5 GB miễn phí mỗi tháng,
# một Lambda lỗi lặp vô hạn cũng đủ ăn hết. Script này ép retention cho mọi log group.
#
#   ./scripts/set-log-retention.sh          → 7 ngày (mặc định)
#   ./scripts/set-log-retention.sh 3        → 3 ngày
#   ./scripts/set-log-retention.sh 7 --dry  → chỉ in ra, không sửa
set -euo pipefail

DAYS="${1:-7}"
DRY="${2:-}"
PROFILE="${AWS_PROFILE:-learn}"
REGION="${AWS_REGION:-us-east-1}"

# Giá trị AWS chấp nhận — truyền số khác sẽ bị API từ chối.
VALID="1 3 5 7 14 30 60 90 120 150 180 365 400 545 731 1096 1827 2192 2557 2922 3288 3653"
case " $VALID " in
  *" $DAYS "*) ;;
  *) echo "retention $DAYS không hợp lệ. Chọn một trong: $VALID" >&2; exit 1 ;;
esac

echo "Đặt retention $DAYS ngày cho mọi log group tại $REGION (profile: $PROFILE)"
[ "$DRY" = "--dry" ] && echo "(chế độ dry-run, không sửa gì)"
echo

count=0
skipped=0

while read -r name current; do
  [ -z "$name" ] && continue
  if [ "$current" = "$DAYS" ]; then
    skipped=$((skipped + 1))
    continue
  fi
  printf '  %-60s %s → %s ngày\n' "$name" "${current:-vĩnh viễn}" "$DAYS"
  if [ "$DRY" != "--dry" ]; then
    aws logs put-retention-policy \
      --profile "$PROFILE" --region "$REGION" \
      --log-group-name "$name" --retention-in-days "$DAYS"
  fi
  count=$((count + 1))
done < <(
  aws logs describe-log-groups \
    --profile "$PROFILE" --region "$REGION" \
    --query 'logGroups[].[logGroupName,retentionInDays]' --output text \
  | sed 's/\tNone$/\t/'
)

echo
echo "Đã sửa: $count   ·   Vốn đã đúng: $skipped"
