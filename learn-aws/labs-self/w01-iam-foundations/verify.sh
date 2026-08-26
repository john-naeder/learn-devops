#!/usr/bin/env bash
# Trọng tài của lab tuần 1.
#
# Không đọc một dòng .tf nào. Mọi câu hỏi đều hỏi thẳng AWS:
#   - IAM Policy Simulator trả lời "nếu danh tính X gọi action Y lên Z thì sao"
#     mà không thật sự gọi — đây là thứ bạn chạy trước mỗi lần sửa policy production.
#   - Ba check phủ định thì gọi thật: request ẩn danh, request không TLS,
#     và mượn role thiếu chuỗi bí mật.
#
# Chạy lại bao nhiêu lần cũng được. Script này không tạo, không sửa, không xoá gì.
set -uo pipefail
cd "$(dirname "$0")" || exit 1
source ../_lib/check.sh

# Lab tự thực hành luôn chạy bằng profile bị hàng rào bao quanh, không phải `learn`.
export AWS_PROFILE="${LAB_PROFILE:-lab-builder}"
export AWS_REGION="us-east-1"
export AWS_DEFAULT_REGION="us-east-1"

check_init "Tuần 1 — Ai được làm gì: identity / resource / trust policy"

BUCKET=$(need_output bucket_name)            || exit 1
BUCKET_ARN=$(need_output bucket_arn)         || exit 1
P_BC=$(need_output prefix_bao_cao)           || exit 1
P_LUONG=$(need_output prefix_luong)          || exit 1
ANALYST=$(need_output analyst_arn)           || exit 1
APP=$(need_output app_role_arn)              || exit 1
PARTNER=$(need_output partner_role_arn)      || exit 1
EXTID=$(need_output partner_external_id)     || exit 1
CHI_PHI=$(need_output chi_phi)               || exit 1

echo
echo "  chi_phi = $CHI_PHI"

# sim <policy-source-arn> <action> <resource-arn>  ->  in ra allowed|implicitDeny|explicitDeny
sim() {
  aws iam simulate-principal-policy \
    --policy-source-arn "$1" --action-names "$2" --resource-arns "$3" \
    --query 'EvaluationResults[0].EvalDecision' --output text 2>/dev/null || echo "LOI_GOI_API"
}

# quyet <mô tả> <src> <action> <resource> <allowed|denied>
quyet() {
  local mota="$1" src="$2" act="$3" res="$4" mong="$5" kq thuc
  kq=$(sim "$src" "$act" "$res")
  thuc="denied"; [ "$kq" = "allowed" ] && thuc="allowed"
  if [ "$thuc" = "$mong" ]; then
    ok "$mota" "$kq"
  else
    fail "$mota" "$mong" "$kq"
  fi
}

# ---------------------------------------------------------------------------
section "Kho lưu trữ tồn tại và đúng hình dạng (yêu cầu 1)"

assert_cmd_ok "kho tồn tại và bạn đọc được nó" \
  aws s3api head-bucket --bucket "$BUCKET"

assert_contains "tiền tố khu báo cáo kết thúc bằng dấu /" "/" "$P_BC"
assert_contains "tiền tố khu lương kết thúc bằng dấu /"   "/" "$P_LUONG"

SO_BC=$(aws s3api list-objects-v2 --bucket "$BUCKET" --prefix "$P_BC" \
          --query 'length(Contents || `[]`)' --output text 2>/dev/null)
SO_LUONG=$(aws s3api list-objects-v2 --bucket "$BUCKET" --prefix "$P_LUONG" \
          --query 'length(Contents || `[]`)' --output text 2>/dev/null)
assert_ne "khu báo cáo có ít nhất một object để chấm" "0" "${SO_BC:-0}"
assert_ne "khu lương có ít nhất một object để chấm"   "0" "${SO_LUONG:-0}"

# ---------------------------------------------------------------------------
section "PHỦ ĐỊNH — kho không lộ ra internet (yêu cầu 2)"

BPA=$(aws s3api get-public-access-block --bucket "$BUCKET" \
        --query 'PublicAccessBlockConfiguration.[BlockPublicAcls,IgnorePublicAcls,BlockPublicPolicy,RestrictPublicBuckets]' \
        --output text 2>/dev/null | tr -s '[:space:]' ' ' | sed 's/ $//')
assert_eq "cả bốn khoá Block Public Access đều bật" "True True True True" "${BPA:-<không đọc được>}"

MA=$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 \
      "https://${BUCKET}.s3.amazonaws.com/" 2>/dev/null)
if [ "$MA" = "403" ] || [ "$MA" = "404" ]; then
  ok "request ẩn danh từ internet bị từ chối" "HTTP $MA"
else
  fail "request ẩn danh từ internet bị từ chối" "HTTP 403" "HTTP ${MA:-không kết nối được}"
fi

# ---------------------------------------------------------------------------
section "PHỦ ĐỊNH — kho tự chặn đường truyền không mã hoá (yêu cầu 3)"

assert_cmd_ok "kho có gắn một resource policy" \
  aws s3api get-bucket-policy --bucket "$BUCKET"

# Cùng một lệnh, cùng một credential. Khác đúng một chữ: https so với http.
# Nếu chỉ cái thứ hai hỏng thì việc chặn đang nằm đúng chỗ — ở phía kho.
assert_cmd_ok "cùng request đó qua HTTPS thì được chấp nhận" \
  aws s3api list-objects-v2 --bucket "$BUCKET" --max-keys 1

assert_cmd_fail "request qua HTTP (không mã hoá) bị kho từ chối" \
  aws s3api list-objects-v2 --bucket "$BUCKET" --max-keys 1 \
    --endpoint-url "http://s3.amazonaws.com"

# ---------------------------------------------------------------------------
section "Chị Lan — chỉ đọc khu báo cáo (yêu cầu 4)"

quyet "đọc được báo cáo"                  "$ANALYST" s3:GetObject    "${BUCKET_ARN}/${P_BC}bao-cao-thang-01.csv"   allowed
quyet "liệt kê được kho"                  "$ANALYST" s3:ListBucket   "${BUCKET_ARN}"                                allowed
quyet "PHỦ ĐỊNH: không đọc được khu lương" "$ANALYST" s3:GetObject   "${BUCKET_ARN}/${P_LUONG}thang-01.csv"         denied
quyet "không ghi được"                    "$ANALYST" s3:PutObject    "${BUCKET_ARN}/${P_BC}gia-mao.csv"             denied
quyet "không xoá được"                    "$ANALYST" s3:DeleteObject "${BUCKET_ARN}/${P_BC}bao-cao-thang-01.csv"    denied
quyet "không đụng được kho của người khác" "$ANALYST" s3:GetObject   "arn:aws:s3:::kho-cua-nguoi-khac/x.csv"        denied

# ---------------------------------------------------------------------------
section "Job tổng hợp — ghi thêm, không xoá, không có khoá dài hạn (yêu cầu 5)"

assert_contains "danh tính này là role, không phải user" ":role/" "$APP"

quyet "ghi được báo cáo mới"               "$APP" s3:PutObject    "${BUCKET_ARN}/${P_BC}bao-cao-thang-02.csv" allowed
quyet "PHỦ ĐỊNH: không xoá được object"    "$APP" s3:DeleteObject "${BUCKET_ARN}/${P_BC}bao-cao-thang-01.csv" denied
quyet "PHỦ ĐỊNH: không đọc được khu lương" "$APP" s3:GetObject    "${BUCKET_ARN}/${P_LUONG}thang-01.csv"       denied

KEYS=$(aws iam list-access-keys --user-name "${APP##*/}" \
         --query 'length(AccessKeyMetadata)' --output text 2>/dev/null)
if [ -z "$KEYS" ] || [ "$KEYS" = "None" ]; then
  ok "không có access key dài hạn nào tồn tại cho danh tính này" "role không có access key"
else
  fail "không có access key dài hạn nào tồn tại cho danh tính này" "0" "$KEYS"
fi

# ---------------------------------------------------------------------------
section "Công ty kiểm toán — mượn danh tính có điều kiện (yêu cầu 6)"

assert_contains "danh tính cho kiểm toán là role" ":role/" "$PARTNER"

assert_cmd_ok "mượn được khi xuất trình đúng chuỗi bí mật" \
  aws sts assume-role --role-arn "$PARTNER" --role-session-name kiem-toan-dung \
    --external-id "$EXTID" --duration-seconds 900

assert_cmd_fail "PHỦ ĐỊNH: mượn KHÔNG kèm chuỗi bí mật thì thất bại" \
  aws sts assume-role --role-arn "$PARTNER" --role-session-name kiem-toan-thieu \
    --duration-seconds 900

assert_cmd_fail "PHỦ ĐỊNH: mượn với chuỗi bí mật SAI thì thất bại" \
  aws sts assume-role --role-arn "$PARTNER" --role-session-name kiem-toan-sai \
    --external-id "chuoi-doan-bua-$RANDOM" --duration-seconds 900

quyet "kiểm toán đọc được báo cáo"          "$PARTNER" s3:GetObject "${BUCKET_ARN}/${P_BC}bao-cao-thang-01.csv" allowed
quyet "PHỦ ĐỊNH: kiểm toán không đọc lương" "$PARTNER" s3:GetObject "${BUCKET_ARN}/${P_LUONG}thang-01.csv"      denied

# ---------------------------------------------------------------------------
section "PHỦ ĐỊNH — không danh tính nào tự nới quyền được (yêu cầu 7)"

for ARN in "$ANALYST" "$APP" "$PARTNER"; do
  TEN="${ARN##*/}"
  quyet "$TEN không gắn thêm policy cho mình được"  "$ARN" iam:AttachRolePolicy "$ARN" denied
  quyet "$TEN không sửa policy nội tuyến của mình"  "$ARN" iam:PutRolePolicy    "$ARN" denied
  quyet "$TEN không tạo bản policy mới được"        "$ARN" iam:CreatePolicyVersion "arn:aws:iam::aws:policy/AdministratorAccess" denied
  quyet "$TEN không sửa được resource policy của kho" "$ARN" s3:PutBucketPolicy "$BUCKET_ARN" denied
done

summary

cat <<'EOF'

Hai câu tự hỏi trước khi mở DOI-CHIEU.md:

  1. Check "request qua HTTP bị từ chối" xanh. Nhưng nếu ngày mai bạn tạo thêm
     một danh tính thứ tư và quên hết mọi thứ về TLS — kho có còn từ chối nó
     không? Nếu có, vì sao? Nếu không, bạn đã đặt việc chặn sai chỗ.

  2. Ba check "không tự nới quyền được" trả về implicitDeny hay explicitDeny?
     Chạy lại một cái bằng tay mà xem. Hai giá trị đó chống lại được những kiểu
     sai lầm khác nhau — kiểu nào?
EOF
