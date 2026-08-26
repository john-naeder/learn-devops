#!/usr/bin/env bash
# Quét những thứ hay bị bỏ quên sau buổi lab và vẫn âm thầm tính tiền.
# Chỉ ĐỌC, không xóa gì. In ra lệnh xóa để bạn tự copy nếu muốn.
#
#   ./scripts/find-orphans.sh              → quét us-east-1
#   ./scripts/find-orphans.sh us-west-2    → quét region khác
#   ./scripts/find-orphans.sh --all        → quét MỌI region (chậm, nhưng đây là
#                                            cách duy nhất bắt được đồ bỏ quên ở
#                                            region bạn mở một lần rồi không quay lại)
set -uo pipefail

PROFILE="${AWS_PROFILE:-learn}"
FOUND=0

q() { aws --profile "$PROFILE" --region "$1" "${@:2}" 2>/dev/null; }

hit() {                       # hit <mô tả> <nội dung> <lệnh xóa gợi ý>
  [ -z "${2//[[:space:]]/}" ] && return 0
  FOUND=1
  printf '\n  \033[1;31m● %s\033[0m\n' "$1"
  printf '%s\n' "$2" | sed 's/^/      /'
  [ -n "${3:-}" ] && printf '      \033[2mxóa: %s\033[0m\n' "$3"
  return 0
}

scan_region() {
  local R="$1"
  local before=$FOUND
  printf '\n\033[1m=== %s ===\033[0m\n' "$R"

  hit "EC2 đang chạy (~\$7,5/tháng mỗi con t3.micro)" \
    "$(q "$R" ec2 describe-instances \
        --filters Name=instance-state-name,Values=running,pending \
        --query 'Reservations[].Instances[].[InstanceId,InstanceType,LaunchTime]' \
        --output text)" \
    "aws ec2 terminate-instances --region $R --instance-ids <id>"

  hit "EBS volume mồ côi, trạng thái available (~\$0,08/GB/tháng)" \
    "$(q "$R" ec2 describe-volumes --filters Name=status,Values=available \
        --query 'Volumes[].[VolumeId,Size,CreateTime]' --output text)" \
    "aws ec2 delete-volume --region $R --volume-id <id>"

  hit "Elastic IP không gắn vào đâu (~\$3,6/tháng mỗi cái)" \
    "$(q "$R" ec2 describe-addresses \
        --query 'Addresses[?AssociationId==null].[PublicIp,AllocationId]' --output text)" \
    "aws ec2 release-address --region $R --allocation-id <id>"

  hit "Load Balancer (~\$17/tháng mỗi cái)" \
    "$(q "$R" elbv2 describe-load-balancers \
        --query 'LoadBalancers[].[LoadBalancerName,Type,CreatedTime]' --output text)" \
    "aws elbv2 delete-load-balancer --region $R --load-balancer-arn <arn>"

  hit "NAT Gateway (~\$33/tháng mỗi cái — kẻ giết credit số 1)" \
    "$(q "$R" ec2 describe-nat-gateways \
        --filter Name=state,Values=available,pending \
        --query 'NatGateways[].[NatGatewayId,VpcId,CreateTime]' --output text)" \
    "aws ec2 delete-nat-gateway --region $R --nat-gateway-id <id>"

  hit "VPC Interface Endpoint (~\$7,2/tháng mỗi cái mỗi AZ)" \
    "$(q "$R" ec2 describe-vpc-endpoints \
        --filters Name=vpc-endpoint-type,Values=Interface \
        --query 'VpcEndpoints[].[VpcEndpointId,ServiceName]' --output text)" \
    "aws ec2 delete-vpc-endpoints --region $R --vpc-endpoint-ids <id>"

  hit "RDS instance (~\$14/tháng mỗi db.t4g.micro)" \
    "$(q "$R" rds describe-db-instances \
        --query 'DBInstances[].[DBInstanceIdentifier,DBInstanceClass,DBInstanceStatus]' --output text)" \
    "aws rds delete-db-instance --region $R --db-instance-identifier <id> --skip-final-snapshot"

  hit "RDS snapshot thủ công (tính tiền theo dung lượng)" \
    "$(q "$R" rds describe-db-snapshots --snapshot-type manual \
        --query 'DBSnapshots[].[DBSnapshotIdentifier,AllocatedStorage]' --output text)" \
    "aws rds delete-db-snapshot --region $R --db-snapshot-identifier <id>"

  hit "EBS snapshot tự tạo (~\$0,05/GB/tháng)" \
    "$(q "$R" ec2 describe-snapshots --owner-ids self \
        --query 'Snapshots[].[SnapshotId,VolumeSize,StartTime]' --output text)" \
    "aws ec2 delete-snapshot --region $R --snapshot-id <id>"

  hit "Auto Scaling Group (tự dựng lại instance bạn vừa terminate)" \
    "$(q "$R" autoscaling describe-auto-scaling-groups \
        --query 'AutoScalingGroups[].[AutoScalingGroupName,DesiredCapacity,MinSize]' --output text)" \
    "aws autoscaling delete-auto-scaling-group --region $R --auto-scaling-group-name <ten> --force-delete"

  hit "EKS cluster (~\$73/tháng — ngoài phạm vi SAA, không nên có)" \
    "$(q "$R" eks list-clusters --query 'clusters' --output text)" \
    "aws eks delete-cluster --region $R --name <ten>"

  [ "$FOUND" = "$before" ] && echo "  sạch"
  return 0
}

if [ "${1:-}" = "--all" ]; then
  echo "Quét mọi region đang bật — sẽ mất một lúc..."
  REGIONS=$(aws --profile "$PROFILE" ec2 describe-regions \
              --query 'Regions[].RegionName' --output text)
else
  REGIONS="${1:-${AWS_REGION:-us-east-1}}"
fi

for r in $REGIONS; do scan_region "$r"; done

# ---- Những thứ không gắn với region -----------------------------------------
printf '\n\033[1m=== Toàn cục ===\033[0m\n'
before=$FOUND
hit "Route 53 hosted zone (\$0,50/tháng mỗi zone)" \
  "$(aws --profile "$PROFILE" route53 list-hosted-zones \
      --query 'HostedZones[].[Name,Id]' --output text 2>/dev/null)" \
  "aws route53 delete-hosted-zone --id <id>"

hit "KMS customer managed key (\$1/tháng mỗi key)" \
  "$(aws --profile "$PROFILE" --region "${AWS_REGION:-us-east-1}" kms list-keys \
      --query 'Keys[].KeyId' --output text 2>/dev/null \
    | tr '\t' '\n' | while read -r k; do
        [ -z "$k" ] && continue
        aws --profile "$PROFILE" --region "${AWS_REGION:-us-east-1}" kms describe-key --key-id "$k" \
          --query 'KeyMetadata.[KeyId,KeyManager,KeyState]' --output text 2>/dev/null \
          | grep -w CUSTOMER | grep -w Enabled
      done)" \
  "aws kms schedule-key-deletion --key-id <id> --pending-window-in-days 7"

hit "Secrets Manager secret (\$0,40/tháng mỗi cái — dùng Parameter Store thay thế)" \
  "$(aws --profile "$PROFILE" --region "${AWS_REGION:-us-east-1}" secretsmanager list-secrets \
      --query 'SecretList[].Name' --output text 2>/dev/null)" \
  "aws secretsmanager delete-secret --secret-id <ten> --force-delete-without-recovery"
[ "$FOUND" = "$before" ] && echo "  sạch"

echo
if [ "$FOUND" = 0 ]; then
  echo "Không tìm thấy gì đang đốt tiền. Đóng máy được rồi."
else
  echo "Có đồ đang chạy ở trên. Nếu buổi lab đã xong, ưu tiên:"
  echo "  cd labs/<lab đang làm>/terraform && terraform destroy"
  echo "vì destroy xóa đúng thứ tự phụ thuộc, còn xóa tay thì rất dễ sót."
fi
