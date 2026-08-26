#!/usr/bin/env bash
# ===========================================================================
# guard.sh — chạy TRƯỚC mỗi buổi lab. Mất 10 giây, cứu được vài chục đô.
#
#   source ../../env.sh
#   export AWS_PROFILE=lab-builder
#   ./_boundary/guard.sh
#
# Sáu việc, theo đúng thứ tự quan trọng:
#   1. bạn đang là AI      — sai danh tính là hỏng mọi hàng rào phía sau
#   2. bạn đang ở ĐÂU      — region sai là công thức để quên tài nguyên
#   3. hàng rào còn đứng   — boundary tồn tại và đang gắn vào role
#   4. lưới an toàn còn    — budget còn sống
#   5. còn gì đang chạy    — tàn dư buổi trước
#   6. tháng này tiêu bao nhiêu
#
# Script CHỈ ĐỌC. Nó không sửa, không tạo, không xoá gì.
# Exit 1 nếu một trong bốn kiểm tra đầu hỏng.
# ===========================================================================
set -uo pipefail
cd "$(dirname "$0")" || exit 1

source ../_lib/check.sh

# --- Cấu hình, đều có thể ghi đè bằng biến môi trường -----------------------
PROFILE="${AWS_PROFILE:-lab-builder}"
ROLE_NAME="${LABS_SELF_ROLE:-lab-builder}"
BOUNDARY_NAME="${LABS_SELF_BOUNDARY:-labs-self-boundary}"
BUDGET_NAME="${LABS_SELF_BUDGET:-labs-self-budget}"
REGION_DUNG="${LABS_SELF_REGION:-us-east-1}"

# Nếu state của _boundary có sẵn ở máy này thì lấy tên thật từ đó — chính xác
# hơn là đoán theo mặc định.
if [ -f terraform.tfstate ] || [ -d .terraform ]; then
  _tmp="$(terraform output -no-color -raw budget_name 2>/dev/null)"
  case "$_tmp" in *[!\ ]*) [ "${_tmp#*Warning}" = "$_tmp" ] && BUDGET_NAME="$_tmp" ;; esac
fi

aws_() { aws --profile "$PROFILE" "$@"; }

check_init "guard.sh — kiểm tra hàng rào trước buổi lab   (profile: $PROFILE)"

# ===========================================================================
# 1. Bạn đang là ai
# ===========================================================================
section "1. Danh tính"

CALLER_JSON="$(aws_ sts get-caller-identity --output json 2>/dev/null)"

if [ -z "$CALLER_JSON" ]; then
  fail "gọi được sts:GetCallerIdentity" \
    "credential hợp lệ cho profile $PROFILE" \
    "không lấy được danh tính"
  printf '\n'
  printf '      Thường là một trong ba lý do:\n'
  printf '        - chưa có [profile %s] trong ~/.aws/config\n' "$PROFILE"
  printf '        - profile nguồn (source_profile) hết hạn hoặc sai key\n'
  printf '        - chưa apply _boundary nên role %s chưa tồn tại\n\n' "$ROLE_NAME"
  printf '      Xem lại output "aws_config_profile" của terraform trong thư mục này.\n'
  ARN=""
  ACCOUNT=""
else
  ARN="$(printf '%s' "$CALLER_JSON" | sed -n 's/.*"Arn"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"
  ACCOUNT="$(printf '%s' "$CALLER_JSON" | sed -n 's/.*"Account"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"

  case "$ARN" in
  *":root")
    # BÁO ĐỘNG ĐỎ. Root bỏ qua MỌI permission boundary, MỌI SCP, MỌI Deny.
    # Không có hàng rào nào tồn tại khi bạn là root.
    printf '\n'
    printf '%s  ####################################################################%s\n' "$_C_RED$_C_BOLD" "$_C_OFF"
    printf '%s  #  BÁO ĐỘNG ĐỎ — BẠN ĐANG DÙNG ROOT ACCOUNT                        #%s\n' "$_C_RED$_C_BOLD" "$_C_OFF"
    printf '%s  ####################################################################%s\n' "$_C_RED$_C_BOLD" "$_C_OFF"
    printf '\n'
    printf '      %s\n\n' "$ARN"
    printf '      Root KHÔNG bị permission boundary chặn. Không bị SCP chặn.\n'
    printf '      Không bị bất cứ Deny nào chặn. Mọi hàng rào trong repo này\n'
    printf '      đều VÔ HIỆU khi bạn là root — kể cả những cái guard.sh sắp báo xanh.\n\n'
    printf '      Dừng lại. Đăng xuất root. Bật MFA cho root nếu chưa. Rồi:\n'
    printf '        export AWS_PROFILE=%s\n\n' "$ROLE_NAME"
    fail "KHÔNG được là root" "assumed-role/$ROLE_NAME/..." "$ARN"
    ;;
  *":user/"*)
    fail "phải là role, không phải IAM user" "assumed-role/$ROLE_NAME/..." "$ARN"
    printf '\n'
    printf '      IAM user gắn access key dài hạn. Rò rỉ là sống mãi tới khi bạn\n'
    printf '      phát hiện, và user %s nhiều khả năng là admin không có boundary.\n' "$(basename "$ARN")"
    printf '      Dùng nó để làm lab là bỏ qua toàn bộ hàng rào.\n\n'
    ;;
  *"assumed-role/$ROLE_NAME/"*)
    ok "đang assume role $ROLE_NAME" "$ARN"
    ;;
  *)
    fail "đúng role làm lab" "assumed-role/$ROLE_NAME/..." "$ARN"
    printf '\n'
    printf '      Bạn đang là một danh tính khác. Nó có thể là admin, và admin\n'
    printf '      thì không có permission boundary — sai một lệnh là mất tiền thật.\n\n'
    ;;
  esac
fi

# ===========================================================================
# 2. Bạn đang ở đâu
# ===========================================================================
section "2. Region"

REGION="${AWS_REGION:-${AWS_DEFAULT_REGION:-}}"
[ -z "$REGION" ] && REGION="$(aws_ configure get region 2>/dev/null)"
assert_eq "region hiệu dụng" "$REGION_DUNG" "${REGION:-<chưa đặt>}"

if [ "${REGION:-}" != "$REGION_DUNG" ]; then
  printf '\n'
  printf '      Sửa:  source ../../env.sh    (đặt AWS_REGION=%s)\n\n' "$REGION_DUNG"
fi

# ===========================================================================
# 3. Hàng rào còn đứng không
# ===========================================================================
section "3. Permission boundary"

if [ -n "$ACCOUNT" ]; then
  BOUNDARY_ARN="arn:aws:iam::${ACCOUNT}:policy/${BOUNDARY_NAME}"

  if aws_ iam get-policy --policy-arn "$BOUNDARY_ARN" >/dev/null 2>&1; then
    ok "policy boundary tồn tại" "$BOUNDARY_NAME"
  else
    fail "policy boundary tồn tại" "$BOUNDARY_ARN" "không tìm thấy"
    printf '\n      Chưa dựng hàng rào. Đọc README.md trong thư mục này.\n\n'
  fi

  GAN="$(aws_ iam get-role --role-name "$ROLE_NAME" \
    --query 'Role.PermissionsBoundary.PermissionsBoundaryArn' \
    --output text 2>/dev/null)"
  [ "$GAN" = "None" ] && GAN=""
  assert_eq "boundary đang gắn vào role $ROLE_NAME" "$BOUNDARY_ARN" "${GAN:-<không gắn>}"

  # Bằng chứng SỐNG, không phải tra sổ sách: gọi một API chỉ-đọc ở region
  # KHÁC us-east-1. Boundary phải từ chối. Nếu lệnh này chạy được, hàng rào
  # đang thủng dù ba dòng trên có xanh.
  assert_cmd_fail "hàng rào chặn thật (thử đọc EC2 ở us-west-2)" \
    aws --profile "$PROFILE" --region us-west-2 ec2 describe-instances --max-items 1
else
  fail "kiểm tra được boundary" "biết account id" "chưa xác định được danh tính"
fi

# ===========================================================================
# 4. Lưới an toàn cuối cùng
# ===========================================================================
section "4. Ngân sách"

if [ -n "$ACCOUNT" ]; then
  BUDGET_JSON="$(aws_ budgets describe-budget \
    --account-id "$ACCOUNT" --budget-name "$BUDGET_NAME" \
    --output json 2>/dev/null)"

  if [ -n "$BUDGET_JSON" ]; then
    TRAN="$(printf '%s' "$BUDGET_JSON" | tr -d ' \n' | sed -n 's/.*"BudgetLimit":{"Amount":"\([^"]*\)".*/\1/p')"
    DA_TIEU="$(printf '%s' "$BUDGET_JSON" | tr -d ' \n' | sed -n 's/.*"ActualSpend":{"Amount":"\([^"]*\)".*/\1/p')"
    ok "budget $BUDGET_NAME còn sống" "trần \$${TRAN:-?} — đã tiêu \$${DA_TIEU:-?}"
  else
    fail "budget $BUDGET_NAME còn sống" "budget tồn tại" "không tìm thấy"
    printf '\n'
    printf '      Boundary chặn "tạo cái đắt tiền". Budget bắt "cái rẻ tiền chạy\n'
    printf '      quên tắt 30 ngày". Thiếu budget là mất hẳn tầng phòng thủ thứ hai.\n\n'
  fi
else
  fail "kiểm tra được budget" "biết account id" "chưa xác định được danh tính"
fi

# --- Bốn kiểm tra cứng đã xong. Hỏng thì dừng tại đây. ---------------------
if [ "$(check_failures)" -gt 0 ]; then
  printf '\n'
  printf '%sHàng rào chưa sẵn sàng — không bắt đầu buổi lab.%s\n' "$_C_YELLOW$_C_BOLD" "$_C_OFF"
  printf 'Bỏ qua bước 5 và 6 vì chúng cần danh tính đúng mới cho số liệu đúng.\n'
  summary
fi

# ===========================================================================
# 5. Còn gì đang đốt tiền
# ===========================================================================
section "5. Tài nguyên đang tốn tiền"

ORPHANS="../../scripts/find-orphans.sh"
if [ -x "$ORPHANS" ]; then
  # Tái dùng script đã có thay vì viết lại: nó biết giá của từng loại tài
  # nguyên và in sẵn lệnh xoá.
  AWS_PROFILE="$PROFILE" AWS_REGION="$REGION_DUNG" "$ORPHANS"
else
  printf '  %skhông tìm thấy %s — quét tay:%s\n' "$_C_DIM" "$ORPHANS" "$_C_OFF"
  aws_ --region "$REGION_DUNG" ec2 describe-instances \
    --filters Name=instance-state-name,Values=running,pending \
    --query 'Reservations[].Instances[].[InstanceId,InstanceType]' --output text 2>/dev/null
fi

# ===========================================================================
# 6. Chi tiêu tháng này
# ===========================================================================
section "6. Chi tiêu tháng này"

# Cost Explorer API tính $0,01 mỗi request. Một lần mỗi buổi lab thì không
# đáng kể — nhưng đừng đưa vào vòng lặp.
THANG_DAU="$(date +%Y-%m-01)"
NGAY_MAI="$(date -d 'tomorrow' +%F 2>/dev/null || date -v+1d +%F)"

TIEU="$(aws_ ce get-cost-and-usage \
  --time-period "Start=${THANG_DAU},End=${NGAY_MAI}" \
  --granularity MONTHLY --metrics UnblendedCost \
  --query 'ResultsByTime[0].Total.UnblendedCost.Amount' \
  --output text 2>/dev/null)"

if [ -n "$TIEU" ] && [ "$TIEU" != "None" ]; then
  printf '  từ %s đến hôm nay: %s$%.4f%s\n' "$THANG_DAU" "$_C_BOLD" "$TIEU" "$_C_OFF"
  printf '  %stách theo service: ../../scripts/cost-check.sh 30%s\n' "$_C_DIM" "$_C_OFF"
else
  printf '  %skhông đọc được Cost Explorer (số liệu trễ tới 24 giờ ở account mới)%s\n' \
    "$_C_DIM" "$_C_OFF"
fi

# ===========================================================================
summary

printf '\n'
printf 'Hàng rào đứng vững. Ba điều nó vẫn KHÔNG cứu được bạn:\n'
printf '  - tài nguyên rẻ chạy quên tắt cả tháng   -> terraform destroy sau buổi lab\n'
printf '  - tiền theo lượng dữ liệu và số request  -> đọc output chi_phi trước khi gõ yes\n'
printf '  - thứ đã tạo TRƯỚC khi có hàng rào       -> ../../scripts/find-orphans.sh --all\n'
