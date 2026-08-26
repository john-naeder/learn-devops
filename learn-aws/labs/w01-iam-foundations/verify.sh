#!/usr/bin/env bash
# Kiểm chứng lab tuần 1 bằng IAM Policy Simulator.
#
# Policy Simulator hỏi "nếu danh tính X gọi action Y lên resource Z thì sao"
# mà KHÔNG thực sự gọi. Trong đời thật đây là thứ bạn chạy trước mỗi lần sửa
# policy production.
set -uo pipefail
cd "$(dirname "$0")/terraform"

PROFILE="${AWS_PROFILE:-learn}"
USER_ARN=$(terraform output -raw reader_user_arn 2>/dev/null) || {
  echo "Chưa apply. Chạy: cd terraform && terraform apply"; exit 1; }
BUCKET_ARN=$(terraform output -raw bucket_arn)
ROLE_ARN=$(terraform output -raw ec2_role_arn)

pass=0; fail=0

check() {   # check <mô tả> <arn nguồn> <action> <resource> <kỳ vọng>
  local mota="$1" src="$2" act="$3" res="$4" mong="$5"
  local kq
  kq=$(aws iam simulate-principal-policy --profile "$PROFILE" \
        --policy-source-arn "$src" --action-names "$act" --resource-arns "$res" \
        --query 'EvaluationResults[0].EvalDecision' --output text 2>/dev/null)

  # allowed | implicitDeny | explicitDeny
  local thuc="denied"; [ "$kq" = "allowed" ] && thuc="allowed"

  if [ "$thuc" = "$mong" ]; then
    printf '  \033[32m✓\033[0m %-46s %s\n' "$mota" "$kq"; pass=$((pass+1))
  else
    printf '  \033[31m✗\033[0m %-46s %s (mong đợi %s)\n' "$mota" "$kq" "$mong"; fail=$((fail+1))
  fi
}

echo
echo "User $(basename "$USER_ARN") — identity policy chỉ cho đọc"
check "đọc object trong bucket lab"   "$USER_ARN" s3:GetObject      "$BUCKET_ARN/readme.txt" allowed
check "liệt kê bucket lab"            "$USER_ARN" s3:ListBucket     "$BUCKET_ARN"            allowed
check "ghi đè object"                 "$USER_ARN" s3:PutObject      "$BUCKET_ARN/readme.txt" denied
check "xóa object"                    "$USER_ARN" s3:DeleteObject   "$BUCKET_ARN/readme.txt" denied
check "sửa bucket policy"             "$USER_ARN" s3:PutBucketPolicy "$BUCKET_ARN"           denied
check "đọc bucket KHÁC"               "$USER_ARN" s3:GetObject      "arn:aws:s3:::bucket-nguoi-khac/x" denied

echo
echo "Role $(basename "$ROLE_ARN") — cùng identity policy, khác cách được dùng"
check "role đọc được object"          "$ROLE_ARN" s3:GetObject      "$BUCKET_ARN/readme.txt" allowed
check "role vẫn không ghi được"       "$ROLE_ARN" s3:PutObject      "$BUCKET_ARN/readme.txt" denied

echo
printf 'Đạt: %d   Hỏng: %d\n' "$pass" "$fail"

if [ "$fail" -eq 0 ]; then
  cat <<'EOF'

Tất cả đúng như thiết kế. Hai câu tự hỏi trước khi sang tuần 2:

  1. User và role dùng CHUNG một policy, quyền y hệt nhau. Vậy khác nhau ở đâu?
     (Gợi ý: cái nào có credential dài hạn, cái nào không?)

  2. verify.sh cho thấy user đọc được cả private/luong.txt. Hãy sửa
     data.aws_iam_policy_document.reader trong main.tf để chặn riêng tiền tố
     "private/", rồi chạy lại. Có ít nhất hai cách làm — thêm Deny statement,
     hoặc thu hẹp Resource. Cách nào an toàn hơn khi về sau có người thêm Allow?
EOF
else
  echo
  echo "Có kiểm tra hỏng. Xem lại Resource ARN trong main.tf — nhớ phân biệt"
  echo "  arn:aws:s3:::bucket    (bản thân bucket, cho ListBucket)"
  echo "  arn:aws:s3:::bucket/*  (object bên trong, cho GetObject)"
fi
