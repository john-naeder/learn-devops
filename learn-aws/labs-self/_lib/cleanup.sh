#!/usr/bin/env bash
# ===========================================================================
# cleanup.sh — dọn tài nguyên còn sót của labs-self
#
#   ./_lib/cleanup.sh                      # LIỆT KÊ, không xoá gì (mặc định)
#   ./_lib/cleanup.sh --lab w03            # chỉ tuần 3
#   ./_lib/cleanup.sh --lab w03 --yes      # xoá thật, vẫn phải gõ xác nhận
#
# ---------------------------------------------------------------------------
# ĐỌC TRƯỚC KHI DÙNG
#
# Đây KHÔNG phải cách dọn dẹp chính. Cách chính là:
#
#     cd wXX-ten-lab/terraform && terraform destroy
#
# terraform destroy xoá đúng thứ tự phụ thuộc và biết chính xác nó đã tạo gì.
# Script này xoá theo TAG, nên nó chỉ đoán, và nó xoá không theo state.
# Dùng nó khi destroy đã thất bại, khi state đã mất, hoặc khi bạn từng bấm
# tay trong console.
#
# Sau khi chạy script này, state Terraform của bạn sẽ lệch với thực tế.
# Chạy `terraform state list` rồi dọn state cho khớp, hoặc xoá luôn state.
# ---------------------------------------------------------------------------
set -uo pipefail

PROFILE="${AWS_PROFILE:-lab-builder}"
REGION="${AWS_REGION:-us-east-1}"
TAG_OWNER="labs-self"
LAB=""
XOA_THAT=0

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  R=$'\033[31m' G=$'\033[32m' Y=$'\033[33m' B=$'\033[1m' D=$'\033[2m' O=$'\033[0m'
else
  R='' G='' Y='' B='' D='' O=''
fi

usage() {
  sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

while [ $# -gt 0 ]; do
  case "$1" in
  --lab)
    LAB="${2:-}"
    shift 2
    ;;
  --lab=*)
    LAB="${1#*=}"
    shift
    ;;
  --yes) XOA_THAT=1 && shift ;;
  --dry-run) XOA_THAT=0 && shift ;;
  --profile)
    PROFILE="${2:-}"
    shift 2
    ;;
  --region)
    REGION="${2:-}"
    shift 2
    ;;
  -h | --help) usage 0 ;;
  *)
    printf '%sTham số lạ: %s%s\n\n' "$R" "$1" "$O"
    usage 1
    ;;
  esac
done

aws_() { aws --profile "$PROFILE" --region "$REGION" "$@"; }

# ===========================================================================
# Chốt an toàn
# ===========================================================================
ARN_TOI="$(aws_ sts get-caller-identity --query Arn --output text 2>/dev/null)"

if [ -z "$ARN_TOI" ]; then
  printf '%sKhông lấy được danh tính cho profile "%s". Dừng.%s\n' "$R" "$PROFILE" "$O"
  exit 1
fi

case "$ARN_TOI" in
*":root")
  printf '%s%sTừ chối chạy bằng root.%s Root xoá được mọi thứ trong account,\n' "$R" "$B" "$O"
  printf 'kể cả những thứ không phải của lab. Dùng profile lab-builder.\n'
  exit 1
  ;;
esac

printf '\n%sDọn tài nguyên labs-self%s\n' "$B" "$O"
printf '%s----------------------------------------------------------------------%s\n' "$D" "$O"
printf '  profile : %s (%s)\n' "$PROFILE" "$ARN_TOI"
printf '  region  : %s\n' "$REGION"
printf '  lọc tag : owner=%s' "$TAG_OWNER"
[ -n "$LAB" ] && printf ' , lab=%s' "$LAB"
printf '\n'
if [ "$XOA_THAT" -eq 1 ]; then
  printf '  chế độ  : %sXOÁ THẬT%s\n' "$R$B" "$O"
else
  printf '  chế độ  : %sdry-run — chỉ liệt kê, không xoá gì%s\n' "$G" "$O"
fi
printf '\n'

# ===========================================================================
# Tìm đồ theo tag
#
# Tag owner=labs-self là do default_tags của provider gắn vào mọi resource lab.
# Hàng rào trong _boundary/ mang owner=labs-self-infra — KHÁC CHUỖI, và
# tag-filter của AWS so khớp chính xác, nên hàng rào không bao giờ lọt vào đây.
# ===========================================================================
LOC=(--tag-filters "Key=owner,Values=${TAG_OWNER}")
[ -n "$LAB" ] && LOC+=(--tag-filters "Key=lab,Values=${LAB}")

DS="$(aws_ resourcegroupstaggingapi get-resources "${LOC[@]}" \
  --query 'ResourceTagMappingList[].ResourceARN' --output text 2>/dev/null | tr '\t' '\n' | sed '/^$/d')"

if [ -z "$DS" ]; then
  printf '%sKhông còn tài nguyên nào mang tag owner=%s ở %s.%s\n\n' "$G" "$TAG_OWNER" "$REGION" "$O"
  printf 'Vẫn nên quét thêm những thứ tag không với tới:\n'
  printf '  ../../scripts/find-orphans.sh --all\n\n'
  exit 0
fi

# --- Xếp theo thứ tự xoá ----------------------------------------------------
# Ngược với thứ tự tạo. Xoá ASG trước, nếu không nó dựng lại đúng cái instance
# bạn vừa terminate — và bạn sẽ tưởng script hỏng.
thu_tu() {
  case "$1" in
  arn:aws:autoscaling:*) echo 10 ;;
  arn:aws:elasticloadbalancing:*:loadbalancer/*) echo 20 ;;
  arn:aws:elasticloadbalancing:*:targetgroup/*) echo 25 ;;
  arn:aws:ec2:*:instance/*) echo 30 ;;
  arn:aws:rds:*) echo 35 ;;
  arn:aws:ec2:*:natgateway/*) echo 40 ;;
  arn:aws:ec2:*:vpc-endpoint/*) echo 45 ;;
  arn:aws:ec2:*:elastic-ip/*) echo 50 ;;
  arn:aws:ec2:*:volume/*) echo 55 ;;
  arn:aws:ec2:*:snapshot/*) echo 60 ;;
  arn:aws:lambda:*) echo 65 ;;
  arn:aws:dynamodb:*) echo 70 ;;
  arn:aws:sqs:*) echo 75 ;;
  arn:aws:sns:*) echo 80 ;;
  arn:aws:logs:*) echo 85 ;;
  arn:aws:s3:*) echo 90 ;;
  *) echo 99 ;;
  esac
}

XEP="$(while IFS= read -r a; do [ -n "$a" ] && printf '%s\t%s\n' "$(thu_tu "$a")" "$a"; done <<<"$DS" | sort -n -k1,1 | cut -f2-)"

SO_LUONG="$(printf '%s\n' "$XEP" | sed '/^$/d' | wc -l | tr -d ' ')"

printf '%sTìm thấy %s tài nguyên, xếp theo thứ tự sẽ xoá:%s\n\n' "$B" "$SO_LUONG" "$O"
n=0
while IFS= read -r a; do
  [ -z "$a" ] && continue
  n=$((n + 1))
  if [ "$(thu_tu "$a")" = "99" ]; then
    printf '  %2d. %s  %s<- script không tự xoá, xem cuối bản in%s\n' "$n" "$a" "$Y" "$O"
  else
    printf '  %2d. %s\n' "$n" "$a"
  fi
done <<<"$XEP"
printf '\n'

# ===========================================================================
# Dry-run dừng ở đây
# ===========================================================================
if [ "$XOA_THAT" -eq 0 ]; then
  printf '%sChưa xoá gì cả.%s\n\n' "$G" "$O"
  printf 'Cách đúng, thử trước:\n'
  printf '  cd ../%s*/terraform && terraform destroy\n\n' "${LAB:-wXX}"
  printf 'Nếu destroy không cứu được thì mới dùng script này:\n'
  printf '  %s --yes%s\n' "$0" "${LAB:+ --lab $LAB}"
  printf '\n'
  exit 0
fi

# ===========================================================================
# Xác nhận — bắt buộc, không có cờ nào bỏ qua được
# ===========================================================================
if [ ! -r /dev/tty ]; then
  printf '%sKhông có terminal để hỏi xác nhận. Từ chối xoá.%s\n' "$R" "$O"
  printf 'Script này cố tình không chạy được tự động trong CI hay cron.\n'
  exit 1
fi

printf '%s%s%s tài nguyên ở trên sẽ bị XOÁ VĨNH VIỄN. Không có thùng rác.%s\n' "$R$B" "$SO_LUONG" " " "$O"
printf 'Gõ %sXOA%s để tiếp tục, bất cứ thứ gì khác để huỷ: ' "$B" "$O"
read -r TRA_LOI </dev/tty

if [ "$TRA_LOI" != "XOA" ]; then
  printf '\n%sĐã huỷ. Không xoá gì.%s\n\n' "$G" "$O"
  exit 0
fi
printf '\n'

# ===========================================================================
# Xoá
# ===========================================================================
chay() { # chay <mô tả> <lệnh...>
  local mota="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    printf '  %s✓%s %s\n' "$G" "$O" "$mota"
  else
    printf '  %s✗%s %s  %s(xem lại bằng tay)%s\n' "$R" "$O" "$mota" "$D" "$O"
  fi
}

# Bucket có versioning: xoá file thường KHÔNG làm bucket trống. Phải xoá cả
# version cũ lẫn delete marker. Đây là bẫy destroy kinh điển của tuần 4.
don_bucket() {
  local b="$1" khoa ver
  aws_ s3 rm "s3://$b" --recursive >/dev/null 2>&1
  for loai in Versions DeleteMarkers; do
    while IFS=$'\t' read -r khoa ver; do
      [ -z "${khoa:-}" ] && continue
      aws_ s3api delete-object --bucket "$b" --key "$khoa" --version-id "$ver" >/dev/null 2>&1
    done < <(aws_ s3api list-object-versions --bucket "$b" \
      --query "${loai}[].[Key,VersionId]" --output text 2>/dev/null | sed '/^None/d;/^$/d')
  done
}

CON_LAI=""

while IFS= read -r arn; do
  [ -z "$arn" ] && continue
  ten="${arn##*/}"
  case "$arn" in

  arn:aws:autoscaling:*)
    chay "ASG $ten" aws_ autoscaling delete-auto-scaling-group \
      --auto-scaling-group-name "$ten" --force-delete
    ;;

  arn:aws:elasticloadbalancing:*:loadbalancer/*)
    chay "Load Balancer $ten" aws_ elbv2 delete-load-balancer --load-balancer-arn "$arn"
    ;;

  arn:aws:elasticloadbalancing:*:targetgroup/*)
    chay "Target Group $ten" aws_ elbv2 delete-target-group --target-group-arn "$arn"
    ;;

  arn:aws:ec2:*:instance/*)
    chay "EC2 $ten" aws_ ec2 terminate-instances --instance-ids "$ten"
    ;;

  arn:aws:rds:*:db:*)
    chay "RDS ${arn##*:}" aws_ rds delete-db-instance \
      --db-instance-identifier "${arn##*:}" --skip-final-snapshot --delete-automated-backups
    ;;

  arn:aws:ec2:*:natgateway/*)
    chay "NAT Gateway $ten" aws_ ec2 delete-nat-gateway --nat-gateway-id "$ten"
    ;;

  arn:aws:ec2:*:vpc-endpoint/*)
    chay "VPC Endpoint $ten" aws_ ec2 delete-vpc-endpoints --vpc-endpoint-ids "$ten"
    ;;

  arn:aws:ec2:*:elastic-ip/*)
    chay "Elastic IP $ten" aws_ ec2 release-address --allocation-id "$ten"
    ;;

  arn:aws:ec2:*:volume/*)
    chay "EBS volume $ten" aws_ ec2 delete-volume --volume-id "$ten"
    ;;

  arn:aws:ec2:*:snapshot/*)
    chay "Snapshot $ten" aws_ ec2 delete-snapshot --snapshot-id "$ten"
    ;;

  arn:aws:lambda:*:function:*)
    chay "Lambda ${arn##*:}" aws_ lambda delete-function --function-name "${arn##*:}"
    ;;

  arn:aws:dynamodb:*:table/*)
    chay "DynamoDB $ten" aws_ dynamodb delete-table --table-name "$ten"
    ;;

  arn:aws:sqs:*)
    q="$(aws_ sqs get-queue-url --queue-name "${arn##*:}" --query QueueUrl --output text 2>/dev/null)"
    if [ -n "$q" ] && [ "$q" != "None" ]; then
      chay "SQS ${arn##*:}" aws_ sqs delete-queue --queue-url "$q"
    else
      CON_LAI="${CON_LAI}${arn}"$'\n'
    fi
    ;;

  arn:aws:sns:*)
    chay "SNS ${arn##*:}" aws_ sns delete-topic --topic-arn "$arn"
    ;;

  arn:aws:logs:*:log-group:*)
    lg="${arn%:\*}"
    lg="${lg##*:log-group:}"
    chay "Log group $lg" aws_ logs delete-log-group --log-group-name "$lg"
    ;;

  arn:aws:s3:*)
    b="${arn##*:::}"
    printf '  %s…%s dọn version trong bucket %s\n' "$D" "$O" "$b"
    don_bucket "$b"
    chay "S3 bucket $b" aws_ s3api delete-bucket --bucket "$b"
    ;;

  *)
    CON_LAI="${CON_LAI}${arn}"$'\n'
    ;;
  esac
done <<<"$XEP"

# ===========================================================================
printf '\n'
if [ -n "${CON_LAI//[[:space:]]/}" ]; then
  printf '%sScript không tự xoá những thứ sau:%s\n\n' "$Y$B" "$O"
  printf '%s' "$CON_LAI" | sed 's/^/  /'
  printf '\n'
  printf 'Lý do: chúng hoặc miễn phí (VPC, subnet, security group, IAM role),\n'
  printf 'hoặc cần nhiều bước có thứ tự (CloudFront phải disable rồi đợi ~15 phút).\n'
  printf 'Xoá nhầm chúng gây thiệt hại lớn hơn giữ lại, nên script để bạn quyết định.\n\n'
fi

printf '%sKiểm tra lại — đừng tin script, hãy tin API:%s\n' "$B" "$O"
printf '  %s%s\n' "$0" "${LAB:+ --lab $LAB}"
printf '  ../../scripts/find-orphans.sh --all\n'
printf '  ../../scripts/cost-check.sh 2\n\n'
printf '%sState Terraform giờ đã lệch với thực tế.%s Dọn nốt:\n' "$Y" "$O"
printf '  cd ../%s*/terraform && terraform state list\n\n' "${LAB:-wXX}"
