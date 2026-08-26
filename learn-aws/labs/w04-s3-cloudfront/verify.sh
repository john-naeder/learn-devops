#!/usr/bin/env bash
# Kiểm chứng tuần 4: OAC có thật sự khoá bucket không, cache có hoạt động không.
set -uo pipefail
cd "$(dirname "$0")/terraform"

PROFILE="${AWS_PROFILE:-learn}"
CF=$(terraform output -raw cloudfront_url 2>/dev/null) || {
  echo "Chưa apply. Chạy: cd terraform && terraform apply"; exit 1; }
S3URL=$(terraform output -raw bucket_url)
BUCKET=$(terraform output -raw bucket_name)

pass=0; fail=0
ok()  { printf '  \033[32m✓\033[0m %s\n' "$1"; pass=$((pass+1)); }
bad() { printf '  \033[31m✗\033[0m %s\n' "$1"; fail=$((fail+1)); }

echo
echo "1. CloudFront phục vụ được trang"
CODE=$(curl -s -o /dev/null -w '%{http_code}' --max-time 15 "$CF/")
[ "$CODE" = "200" ] && ok "GET $CF → 200" \
  || bad "GET $CF → $CODE (distribution cần 5-10 phút để deploy xong)"

echo
echo "2. Gọi thẳng S3 PHẢI bị chặn — bằng chứng OAC hoạt động"
S3CODE=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "$S3URL")
[ "$S3CODE" = "403" ] && ok "GET S3 trực tiếp → 403 AccessDenied (đúng)" \
  || bad "GET S3 trực tiếp → $S3CODE — bucket đang hở!"

echo
echo "3. Bucket bị chặn public hoàn toàn"
PAB=$(aws s3api get-public-access-block --profile "$PROFILE" --bucket "$BUCKET" \
       --query 'PublicAccessBlockConfiguration.[BlockPublicAcls,BlockPublicPolicy,IgnorePublicAcls,RestrictPublicBuckets]' \
       --output text 2>/dev/null)
[ "$PAB" = "True	True	True	True" ] && ok "cả 4 công tắc Block Public Access đều bật" \
  || bad "Block Public Access chưa đầy đủ: $PAB"

echo
echo "4. Cache — gọi hai lần xem header x-cache"
H1=$(curl -s -D- -o /dev/null --max-time 15 "$CF/" | grep -i '^x-cache:' | tr -d '\r')
H2=$(curl -s -D- -o /dev/null --max-time 15 "$CF/" | grep -i '^x-cache:' | tr -d '\r')
echo "  lần 1: ${H1:-không có header}"
echo "  lần 2: ${H2:-không có header}"
echo "$H2" | grep -qi 'Hit' && ok "lần 2 trả từ cache edge (Hit)" \
  || printf '  \033[33m◐\033[0m chưa Hit — bình thường nếu vừa invalidate hoặc mới deploy\n'

echo
echo "5. Security header do CloudFront Function chèn"
HDRS=$(curl -s -D- -o /dev/null --max-time 15 "$CF/")
for h in strict-transport-security x-content-type-options x-frame-options referrer-policy; do
  echo "$HDRS" | grep -qi "^$h:" && ok "$h có mặt" || bad "thiếu $h"
done

echo
echo "6. Versioning đang bật"
VER=$(aws s3api get-bucket-versioning --profile "$PROFILE" --bucket "$BUCKET" \
       --query 'Status' --output text 2>/dev/null)
[ "$VER" = "Enabled" ] && ok "versioning Enabled" || bad "versioning = $VER"

echo
echo "7. Lifecycle rule"
aws s3api get-bucket-lifecycle-configuration --profile "$PROFILE" --bucket "$BUCKET" \
  --query 'Rules[].[ID,Status]' --output text 2>/dev/null | sed 's/^/  /' \
  || echo "  (chưa có lifecycle rule)"

echo
echo "8. Bucket ở region phụ — bẫy quên kinh điển"
REP=$(terraform output -raw replica_bucket 2>/dev/null || echo "")
if [ -z "$REP" ] || [ "$REP" = "null" ]; then
  ok "CRR đang tắt, không có bucket region phụ nào bị bỏ quên"
else
  printf '  \033[33m◐\033[0m Bucket phụ đang tồn tại: %s (%s)\n' "$REP" "$(terraform output -raw replica_region)"
  printf '     Làm xong bài CRR thì: terraform apply -var enable_crr=false\n'
fi

echo
printf 'Đạt: %d   Hỏng: %d\n' "$pass" "$fail"
cat <<'EOF'

Câu hỏi tự trả lời:

  1. Bucket bị chặn public HOÀN TOÀN mà website vẫn chạy. CloudFront đã
     chứng minh danh tính với S3 bằng cách nào?

  2. Trong bucket policy có điều kiện AWS:SourceArn. Nếu bỏ nó đi thì ai
     đọc được bucket của bạn? (Tra từ khoá "confused deputy".)

  3. Bạn vừa đẩy file mới lên S3 nhưng người dùng vẫn thấy bản cũ.
     Có hai cách xử lý — cách nào miễn phí, và vì sao nó tốt hơn?

  4. Nếu dùng domain riêng thì chứng chỉ ACM phải nằm ở region nào,
     bất kể distribution phục vụ toàn cầu?
EOF
