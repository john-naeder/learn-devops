#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")/terraform"
PROFILE="${AWS_PROFILE:-learn}"
URL=$(terraform output -raw cloudfront_url 2>/dev/null) || { echo "Chưa apply."; exit 1; }

xc() { curl -sD- -o /dev/null --max-time 20 "$1" | grep -i '^x-cache:' | tr -d '\r' | cut -d' ' -f2-; }

echo
echo "════ Hành vi cache theo từng đường dẫn ════"
printf '  %-44s %s\n' "đường dẫn" "x-cache"
for p in "/index.html" "/index.html" "/index.html?utm_source=fb" "/static/data.json" "/static/data.json" "/api/gio.json" "/api/gio.json"; do
  printf '  %-44s %s\n' "$p" "$(xc "$URL$p")"
done

cat <<'EOF'

  Đọc bảng trên như sau:
    /index.html          Miss rồi Hit          → cache mặc định hoạt động
    ?utm_source=fb       vẫn Hit               → utm_* KHÔNG nằm trong cache key
    /static/*            Miss rồi Hit          → cache 1 năm
    /api/*               luôn Miss             → CachingDisabled, đúng cho API
EOF

echo
echo "════ Security header (chèn ở edge) ════"
H=$(curl -sD- -o /dev/null --max-time 20 "$URL/index.html")
for h in strict-transport-security x-content-type-options x-frame-options referrer-policy; do
  if echo "$H" | grep -qi "^$h:"; then
    printf '  \033[32m✓\033[0m %s\n' "$h"
  else
    printf '  \033[31m✗\033[0m %s thiếu\n' "$h"
  fi
done

echo
echo "════ Cache behavior đã cấu hình ════"
aws cloudfront get-distribution-config --profile "$PROFILE" \
  --id "$(terraform output -raw distribution_id)" \
  --query 'DistributionConfig.CacheBehaviors.Items[].[PathPattern,ViewerProtocolPolicy]' \
  --output table 2>/dev/null

echo "════ Route 53 (tốn tiền) ════"
ZONES=$(aws route53 list-hosted-zones --profile "$PROFILE" \
         --query 'HostedZones[].[Name,Id]' --output text 2>/dev/null)
if [ -z "$ZONES" ]; then
  printf '  \033[32m✓\033[0m không có hosted zone nào ($0/tháng)\n'
else
  printf '  \033[33m◐\033[0m hosted zone đang tồn tại — $0,50/tháng mỗi cái:\n'
  printf '%s\n' "$ZONES" | sed 's/^/      /'
fi
HC=$(aws route53 list-health-checks --profile "$PROFILE" --query 'length(HealthChecks)' --output text 2>/dev/null)
[ "${HC:-0}" = "0" ] && printf '  \033[32m✓\033[0m không có health check ($0/tháng)\n' \
  || printf '  \033[33m◐\033[0m %s health check — $0,50/tháng mỗi cái\n' "$HC"

echo
cat <<'EOF'
Câu hỏi tự trả lời:

  1. Nếu đưa TẤT CẢ query string vào cache key, chuyện gì xảy ra với tỉ lệ Hit
     khi bạn chạy một chiến dịch marketing có 50 nguồn utm khác nhau?

  2. Vì sao đưa cookie vào cache key gần như đồng nghĩa với "không cache"?

  3. CloudFront Function và Lambda@Edge — cái nào chạy được ở cả 4 loại sự kiện?
     Cái nào giới hạn 1ms và không có mạng?

  4. Bạn dùng domain riêng cho CloudFront. Chứng chỉ ACM phải tạo ở region nào?

  5. CloudFront và Global Accelerator — cái nào cache nội dung, cái nào tối ưu
     đường mạng? Cái nào cho bạn IP tĩnh?
EOF
