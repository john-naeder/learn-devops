#!/usr/bin/env bash
# Trạng thái sống của lab tuần 3. Chạy lặp lại khi đang làm chaos.yml:
#   watch -n 5 ./verify.sh
set -uo pipefail
cd "$(dirname "$0")/terraform"

PROFILE="${AWS_PROFILE:-learn}"
REGION="${AWS_REGION:-us-east-1}"

ALB=$(terraform output -raw alb_dns_name 2>/dev/null) || {
  echo "Chưa apply. Chạy: cd terraform && terraform apply"; exit 1; }
TG=$(terraform output -raw target_group_arn)
ASG=$(terraform output -raw asg_name)

aws() { command aws --profile "$PROFILE" --region "$REGION" "$@"; }

echo
echo "════ Target Group ════"
aws elbv2 describe-target-health --target-group-arn "$TG" \
  --query 'TargetHealthDescriptions[].[Target.Id,TargetHealth.State,TargetHealth.Reason]' \
  --output table

echo "════ Auto Scaling Group ════"
aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names "$ASG" \
  --query 'AutoScalingGroups[0].{Min:MinSize,Desired:DesiredCapacity,Max:MaxSize,HealthCheck:HealthCheckType}' \
  --output table

aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names "$ASG" \
  --query 'AutoScalingGroups[0].Instances[].[InstanceId,LifecycleState,HealthStatus,AvailabilityZone]' \
  --output table

echo "════ Hoạt động gần đây của ASG ════"
aws autoscaling describe-scaling-activities --auto-scaling-group-name "$ASG" \
  --max-items 4 --query 'Activities[].[StartTime,StatusCode,Description]' --output table 2>/dev/null

echo "════ ALB có luân phiên đổi máy không ════"
declare -A dem
for _ in $(seq 12); do
  iid=$(curl -s --max-time 5 "http://$ALB/" | grep -o 'i-[0-9a-f]*' | head -1)
  [ -n "$iid" ] && dem["$iid"]=$(( ${dem["$iid"]:-0} + 1 ))
done

if [ ${#dem[@]} -eq 0 ]; then
  echo "  Không máy nào trả lời. ALB có thể còn đang khởi tạo (~2-3 phút sau apply)."
else
  for k in "${!dem[@]}"; do printf '  %s  %d/12 request\n' "$k" "${dem[$k]}"; done
  if [ ${#dem[@]} -ge 2 ]; then
    printf '  \033[32m✓\033[0m %d máy đang chia tải\n' "${#dem[@]}"
  else
    printf '  \033[33m◐\033[0m chỉ 1 máy đang phục vụ — bình thường nếu bạn vừa chạy chaos.yml\n'
  fi
fi

echo
echo "════ Chi phí ════"
terraform output -raw chi_phi_moi_gio; echo
echo
echo "Xong thì: terraform destroy"
