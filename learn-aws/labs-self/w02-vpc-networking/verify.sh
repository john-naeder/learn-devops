#!/usr/bin/env bash
# Trọng tài của lab tuần 2.
#
# Không đọc file .tf. Mọi câu hỏi hỏi thẳng AWS, và bốn câu hỏi quan trọng nhất
# thì hỏi thẳng CÁI MÁY của bạn qua Systems Manager Run Command.
#
# Script này đọc trạng thái AWS (không tạo/sửa/xoá tài nguyên nào) và chạy vài
# lệnh chỉ-đọc trên máy chủ của bạn để chứng minh đường mạng thật sự thông.
set -uo pipefail
cd "$(dirname "$0")" || exit 1
source ../_lib/check.sh

export AWS_PROFILE="${LAB_PROFILE:-lab-builder}"
export AWS_REGION="us-east-1"
export AWS_DEFAULT_REGION="us-east-1"

check_init "Tuần 2 — Máy không có cửa: VPC, endpoint, đường ra rẻ nhất"

VPC=$(need_output vpc_id)                || exit 1
PUB_SUBNETS=$(need_output public_subnet_ids)  || exit 1
PRI_SUBNETS=$(need_output private_subnet_ids) || exit 1
INST=$(need_output instance_id)          || exit 1
BUCKET=$(need_output bucket_name)        || exit 1
LG=$(need_output flow_log_group)         || exit 1
CHI_PHI=$(need_output chi_phi)           || exit 1

echo
echo "  chi_phi = $CHI_PHI"

# --- tiện ích ---------------------------------------------------------------

rt_cua_subnet() {   # <subnet-id> -> route-table-id (rơi về main route table nếu chưa gắn riêng)
  local rt
  rt=$(aws ec2 describe-route-tables --filters "Name=association.subnet-id,Values=$1" \
        --query 'RouteTables[0].RouteTableId' --output text 2>/dev/null)
  if [ -z "$rt" ] || [ "$rt" = "None" ]; then
    rt=$(aws ec2 describe-route-tables \
          --filters "Name=vpc-id,Values=$VPC" "Name=association.main,Values=true" \
          --query 'RouteTables[0].RouteTableId' --output text 2>/dev/null)
  fi
  printf '%s' "$rt"
}

dich_mac_dinh() {   # <route-table-id> -> igw-xxx | nat-xxx | eigw-xxx | khong-co
  local d
  d=$(aws ec2 describe-route-tables --route-table-ids "$1" \
        --query "RouteTables[0].Routes[?DestinationCidrBlock=='0.0.0.0/0'].[GatewayId,NatGatewayId,TransitGatewayId]" \
        --output text 2>/dev/null | tr -s '[:space:]' '\n' | grep -v '^None$' | head -1)
  printf '%s' "${d:-khong-co}"
}

# ssm_chay <đoạn shell>  -> in stdout của nó trên máy chủ
# Đóng gói bằng base64 để không phải vật lộn với dấu ngoặc trong JSON.
ssm_chay() {
  local b64 cid st i
  b64=$(printf '%s' "$1" | base64 -w0)
  cid=$(aws ssm send-command --instance-ids "$INST" \
          --document-name AWS-RunShellScript \
          --comment "labs-self w02 verify (chi doc)" \
          --parameters "{\"commands\":[\"echo $b64 | base64 -d | sh\"]}" \
          --query 'Command.CommandId' --output text 2>/dev/null)
  if [ -z "$cid" ] || [ "$cid" = "None" ]; then
    printf 'KHONG_GUI_DUOC_LENH'
    return 1
  fi
  for i in $(seq 1 45); do
    st=$(aws ssm list-command-invocations --command-id "$cid" --details \
          --query 'CommandInvocations[0].Status' --output text 2>/dev/null)
    case "$st" in Success|Failed|TimedOut|Cancelled|Undeliverable) break ;; esac
    sleep 4
  done
  aws ssm list-command-invocations --command-id "$cid" --details \
    --query 'CommandInvocations[0].CommandPlugins[0].Output' --output text 2>/dev/null
}

# ---------------------------------------------------------------------------
section "Hình dạng mạng (yêu cầu 1, 2)"

assert_cmd_ok "VPC tồn tại" aws ec2 describe-vpcs --vpc-ids "$VPC"

SO_AZ=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC" \
          --query 'Subnets[].AvailabilityZone' --output text 2>/dev/null \
          | tr -s '[:space:]' '\n' | sort -u | grep -c '.')
if [ "${SO_AZ:-0}" -ge 2 ]; then
  ok "subnet trải trên ít nhất 2 vùng sẵn sàng" "$SO_AZ AZ"
else
  fail "subnet trải trên ít nhất 2 vùng sẵn sàng" ">= 2 AZ" "${SO_AZ:-0} AZ"
fi

for S in ${PUB_SUBNETS//,/ }; do
  D=$(dich_mac_dinh "$(rt_cua_subnet "$S")")
  case "$D" in
    igw-*) ok "subnet công khai $S có đường ra internet gateway" "0.0.0.0/0 -> $D" ;;
    *)     fail "subnet công khai $S có đường ra internet gateway" "0.0.0.0/0 -> igw-*" "$D" ;;
  esac
done

for S in ${PRI_SUBNETS//,/ }; do
  D=$(dich_mac_dinh "$(rt_cua_subnet "$S")")
  case "$D" in
    khong-co) ok "PHỦ ĐỊNH: subnet riêng tư $S không có đường mặc định ra internet" "không có route 0.0.0.0/0" ;;
    *)        fail "PHỦ ĐỊNH: subnet riêng tư $S không có đường mặc định ra internet" "không có route 0.0.0.0/0" "0.0.0.0/0 -> $D" ;;
  esac
done

# ---------------------------------------------------------------------------
section "PHỦ ĐỊNH — không có NAT Gateway (yêu cầu 9)"

SO_NAT=$(aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=$VPC" \
           --query "length(NatGateways[?State!='deleted'])" --output text 2>/dev/null)
assert_eq "không có NAT Gateway nào trong VPC (\$33/tháng)" "0" "${SO_NAT:-loi}"

SO_EIP=$(aws ec2 describe-addresses \
           --query "length(Addresses[?Tags[?Key=='lab' && Value=='w02']])" --output text 2>/dev/null)
assert_eq "không có Elastic IP nào của lab (\$3,6/tháng mỗi cái)" "0" "${SO_EIP:-loi}"

# ---------------------------------------------------------------------------
section "Máy chủ ở tầng riêng tư (yêu cầu 3)"

read -r TRANG_THAI PUB_IP SUBNET_MAY < <(
  aws ec2 describe-instances --instance-ids "$INST" \
    --query 'Reservations[0].Instances[0].[State.Name,PublicIpAddress,SubnetId]' \
    --output text 2>/dev/null)

assert_eq "máy đang chạy" "running" "${TRANG_THAI:-khong-tim-thay}"
assert_contains "máy nằm trong một subnet riêng tư đã khai báo" "${SUBNET_MAY:-khong-co}" "$PRI_SUBNETS"

if [ "${PUB_IP:-None}" = "None" ] || [ -z "${PUB_IP:-}" ]; then
  ok "PHỦ ĐỊNH: máy không có địa chỉ IP công khai" "PublicIpAddress trống"
else
  fail "PHỦ ĐỊNH: máy không có địa chỉ IP công khai" "trống" "$PUB_IP"
  if timeout 8 bash -c "</dev/tcp/$PUB_IP/22" 2>/dev/null; then
    fail "PHỦ ĐỊNH: SSH từ internet không vào được" "kết nối bị từ chối" "port 22 MỞ trên $PUB_IP"
  else
    ok "cổng 22 trên IP công khai đó không bắt tay được" "$PUB_IP:22 đóng"
  fi
fi

SGS=$(aws ec2 describe-instances --instance-ids "$INST" \
        --query 'Reservations[0].Instances[0].SecurityGroups[].GroupId' --output text 2>/dev/null)
CIDR_MO=$(aws ec2 describe-security-groups --group-ids $SGS \
            --query 'SecurityGroups[].IpPermissions[].IpRanges[].CidrIp' --output text 2>/dev/null)
CIDR6_MO=$(aws ec2 describe-security-groups --group-ids $SGS \
            --query 'SecurityGroups[].IpPermissions[].Ipv6Ranges[].CidrIpv6' --output text 2>/dev/null)
MO_TOANG=$(printf '%s %s' "$CIDR_MO" "$CIDR6_MO" | tr -s '[:space:]' '\n' | grep -c -e '^0\.0\.0\.0/0$' -e '^::/0$')
assert_eq "PHỦ ĐỊNH: không security group nào của máy mở cửa từ cả internet" "0" "${MO_TOANG:-loi}"

# ---------------------------------------------------------------------------
section "Vào được máy mà không mở port nào (yêu cầu 4)"

PING=""
for i in $(seq 1 20); do
  PING=$(aws ssm describe-instance-information \
           --filters "Key=InstanceIds,Values=$INST" \
           --query 'InstanceInformationList[0].PingStatus' --output text 2>/dev/null)
  [ "$PING" = "Online" ] && break
  sleep 6
done
assert_eq "máy đã đăng ký với Systems Manager (agent gọi RA được)" "Online" "${PING:-khong-thay}"

if [ "$PING" != "Online" ]; then
  echo
  echo "  Máy chưa nói chuyện được với Systems Manager nên các check chạy lệnh"
  echo "  từ xa bên dưới sẽ bị bỏ qua. Kiểm tra theo thứ tự:"
  echo "    1) máy có instance profile chưa, role có AmazonSSMManagedInstanceCore chưa"
  echo "    2) agent có đường RA tới ssm, ssmmessages, ec2messages chưa (thiếu"
  echo "       ssmmessages là triệu chứng khó đoán nhất)"
  echo "    3) nếu dùng Interface Endpoint: đã bật private DNS chưa, VPC đã bật"
  echo "       enable_dns_hostnames và enable_dns_support chưa"
  summary
  exit 1
fi

KQ=$(ssm_chay 'echo XIN_CHAO_TU_TRONG_VPC; id -u')
assert_contains "chạy được lệnh trên máy từ laptop, không SSH, không port inbound" \
  "XIN_CHAO_TU_TRONG_VPC" "$KQ"

# ---------------------------------------------------------------------------
section "Ba con đường ra ngoài (yêu cầu 5, 6, 7)"

KQ=$(ssm_chay '
if command -v dnf >/dev/null 2>&1; then
  dnf -q check-update >/dev/null 2>&1; rc=$?
  if [ $rc -eq 0 ] || [ $rc -eq 100 ]; then echo PKG_OK; else echo PKG_FAIL_$rc; fi
elif command -v yum >/dev/null 2>&1; then
  yum -q check-update >/dev/null 2>&1; rc=$?
  if [ $rc -eq 0 ] || [ $rc -eq 100 ]; then echo PKG_OK; else echo PKG_FAIL_$rc; fi
elif command -v apt-get >/dev/null 2>&1; then
  if apt-get update -qq >/dev/null 2>&1; then echo PKG_OK; else echo PKG_FAIL_apt; fi
else
  echo PKG_KHONG_CO_TRINH_QUAN_LY_GOI
fi')
assert_contains "máy tải được danh sách gói từ repo của distro" "PKG_OK" "$KQ"

KQ=$(ssm_chay "aws s3api list-objects-v2 --bucket $BUCKET --max-keys 1 >/dev/null 2>&1 && echo S3_OK || echo S3_FAIL")
assert_contains "máy liệt kê được kho object" "S3_OK" "$KQ"

KQ=$(ssm_chay 'curl -s -m 5 -o /dev/null -w "IMDS_%{http_code}" http://169.254.169.254/latest/meta-data/; echo')
assert_contains "PHỦ ĐỊNH: truy vấn metadata kiểu cũ (không token) bị từ chối" "IMDS_401" "$KQ"

KQ=$(ssm_chay 'T=$(curl -s -m 5 -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 60"); curl -s -m 5 -o /dev/null -w "IMDSV2_%{http_code}" -H "X-aws-ec2-metadata-token: $T" http://169.254.169.254/latest/meta-data/; echo')
assert_contains "nhưng truy vấn metadata có token thì vẫn được" "IMDSV2_200" "$KQ"

# ---------------------------------------------------------------------------
section "PHỦ ĐỊNH — kho object không mở ra internet (yêu cầu 6)"

MA=$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 \
      "https://${BUCKET}.s3.amazonaws.com/" 2>/dev/null)
if [ "$MA" = "403" ] || [ "$MA" = "404" ]; then
  ok "request ẩn danh từ internet vào kho bị từ chối" "HTTP $MA"
else
  fail "request ẩn danh từ internet vào kho bị từ chối" "HTTP 403" "HTTP ${MA:-không kết nối được}"
fi

# ---------------------------------------------------------------------------
section "Dấu vết lưu lượng (yêu cầu 8)"

FL=$(aws ec2 describe-flow-logs --filter "Name=resource-id,Values=$VPC" \
       --query "length(FlowLogs[?FlowLogStatus=='ACTIVE'])" --output text 2>/dev/null)
assert_ne "VPC có ít nhất một Flow Log đang hoạt động" "0" "${FL:-0}"

RET=$(aws logs describe-log-groups --log-group-name-prefix "$LG" \
        --query "logGroups[?logGroupName=='$LG'].retentionInDays | [0]" --output text 2>/dev/null)
if [ "$RET" = "None" ] || [ -z "$RET" ]; then
  fail "log group có thời hạn lưu hữu hạn" "<= 30 ngày" "giữ VĨNH VIỄN (mặc định của CloudWatch)"
elif [ "$RET" -le 30 ] 2>/dev/null; then
  ok "log group có thời hạn lưu hữu hạn" "$RET ngày"
else
  fail "log group có thời hạn lưu hữu hạn" "<= 30 ngày" "$RET ngày"
fi

summary

cat <<'EOF'

Hai câu tự hỏi trước khi mở DOI-CHIEU.md:

  1. Security group của máy không có một rule inbound nào, vậy mà bạn vừa chạy
     lệnh trên nó. Gói tin trả lời đi vào bằng cửa nào? Nếu bạn thay security
     group bằng NACL với cùng bộ rule, còn chạy được không? Vì sao?

  2. Mở bảng giá VPC ra và cộng lại con đường bạn đã chọn. Nếu ngày mai đội dev
     bảo "job cần gọi một API HTTPS của bên thứ ba", con số đó đổi thế nào?
     Câu trả lời khác nhau tuỳ bạn đã chọn đường nào ở yêu cầu 5.
EOF
