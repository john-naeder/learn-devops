#!/usr/bin/env bash
# Kiểm chứng tuần 9 bằng Policy Simulator — ba cơ chế, ba kết quả khác nhau.
set -uo pipefail
cd "$(dirname "$0")/terraform"
PROFILE="${AWS_PROFILE:-learn}"
BND=$(terraform output -raw role_bi_gioi_han_arn 2>/dev/null) || { echo "Chưa apply."; exit 1; }
DENY=$(terraform output -raw role_admin_co_deny_arn)
THIRD=$(terraform output -raw role_ben_thu_ba_arn)

sim() {  # sim <role-arn> <action>
  aws iam simulate-principal-policy --profile "$PROFILE" \
    --policy-source-arn "$1" --action-names "$2" \
    --query 'EvaluationResults[0].EvalDecision' --output text 2>/dev/null
}

mau() {  # tô màu theo kết quả
  case "$1" in
    allowed)      printf '\033[32m%-14s\033[0m' "$1" ;;
    explicitDeny) printf '\033[31m%-14s\033[0m' "$1" ;;
    *)            printf '\033[33m%-14s\033[0m' "$1" ;;
  esac
}

echo
echo "════ Role bị PERMISSION BOUNDARY giới hạn ════"
echo "  (có AdministratorAccess, boundary chỉ cho s3:* và logs:*)"
for a in s3:ListAllMyBuckets logs:DescribeLogGroups iam:CreateUser ec2:RunInstances; do
  printf '  %-28s ' "$a"; mau "$(sim "$BND" "$a")"; echo
done
echo "  → Quyền thực tế = GIAO của identity policy và boundary."
echo "  → Ngoài boundary thì ra implicitDeny: KHÔNG AI cho phép, chứ không phải bị cấm."

echo
echo "════ Role có EXPLICIT DENY ════"
echo "  (có AdministratorAccess + Deny vài hành động nguy hiểm)"
for a in s3:ListAllMyBuckets iam:CreateUser cloudtrail:StopLogging guardduty:DeleteDetector; do
  printf '  %-28s ' "$a"; mau "$(sim "$DENY" "$a")"; echo
done
echo "  → explicitDeny: CÓ NGƯỜI CẤM. Không Allow nào cứu được."

echo
echo "════ AssumeRole với external ID ════"
if aws sts assume-role --profile "$PROFILE" --role-arn "$THIRD" \
     --role-session-name thu-khong-id >/dev/null 2>&1; then
  printf '  \033[31m✗\033[0m assume KHÔNG cần external ID — sai, điều kiện chưa có tác dụng\n'
else
  printf '  \033[32m✓\033[0m không có external ID → AccessDenied (đúng)\n'
fi
if aws sts assume-role --profile "$PROFILE" --role-arn "$THIRD" \
     --role-session-name thu-co-id --external-id "$(terraform output -raw external_id)" >/dev/null 2>&1; then
  printf '  \033[32m✓\033[0m có external ID → thành công (đúng)\n'
else
  printf '  \033[31m✗\033[0m có external ID vẫn thất bại\n'
fi

echo
echo "════ Secret ════"
P=$(terraform output -raw secret_path)
T=$(aws ssm get-parameter --profile "$PROFILE" --name "$P" --query 'Parameter.Type' --output text 2>/dev/null)
[ "$T" = "SecureString" ] && printf '  \033[32m✓\033[0m %s là SecureString\n' "$P" \
                          || printf '  \033[31m✗\033[0m type = %s\n' "$T"
SM=$(aws secretsmanager list-secrets --profile "$PROFILE" --query 'length(SecretList)' --output text 2>/dev/null)
[ "${SM:-0}" = "0" ] && printf '  \033[32m✓\033[0m không dùng Secrets Manager (tiết kiệm $0,40/secret/tháng)\n' \
                     || printf '  \033[33m◐\033[0m %s secret trong Secrets Manager — $0,40/tháng mỗi cái\n' "$SM"

echo
echo "════ GuardDuty ════"
GD=$(aws guardduty list-detectors --profile "$PROFILE" --query 'length(DetectorIds)' --output text 2>/dev/null)
[ "${GD:-0}" = "0" ] && printf '  \033[32m✓\033[0m đang tắt\n' \
                     || printf '  \033[33m◐\033[0m đang bật — tắt khi xem xong: terraform apply -var enable_guardduty=false\n'

echo
cat <<'EOF'
Sơ đồ phải vẽ được từ trí nhớ (nội dung thi):

  Request tới
      │
      ▼
  1. Có EXPLICIT DENY ở bất kỳ đâu?  ──YES──→  TỪ CHỐI. Dừng. Không gì cứu được.
      │ NO
      ▼
  2. SCP của Organizations cho phép? ──NO───→  TỪ CHỐI
      │ YES
      ▼
  3. Permission boundary cho phép?   ──NO───→  TỪ CHỐI
      │ YES
      ▼
  4. Có ALLOW ở identity policy
     HOẶC resource policy?           ──YES──→  CHO PHÉP
      │ NO
      ▼
     TỪ CHỐI  (implicit deny — mặc định của IAM là từ chối)

Ba giá trị Policy Simulator trả về khớp đúng sơ đồ này:
  allowed       bước 4 đúng
  implicitDeny  không ai cho phép  (rơi xuống đáy)
  explicitDeny  có người cấm       (dừng ở bước 1)
EOF
