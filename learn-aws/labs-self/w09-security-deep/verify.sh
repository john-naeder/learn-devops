#!/usr/bin/env bash
# Trọng tài của lab tuần 9.
#
# Lab này chấm những thứ KHÔNG được phép xảy ra, nên phần lớn check ở đây là
# negative check: chúng xanh khi một thứ bị chặn thành công.
#
# Ba cách hỏi AWS, dùng đúng chỗ:
#   1. Mượn role thật rồi gọi API ĐỌC thật  -> chứng minh hành vi thật, không
#      phải cấu hình trên giấy.
#   2. IAM Policy Simulator cho hành động GHI -> hỏi "nếu gọi thì sao" mà không
#      thật sự gọi. Không tạo ra rác, không có rủi ro.
#   3. simulate-custom-policy + --permissions-boundary-policy-input-list -> áp
#      đúng ngữ nghĩa permission boundary lên policy bạn tự viết, bằng chính bộ
#      máy đánh giá quyền của IAM.
#
# Script này CHỈ ĐỌC. Không tạo, không sửa, không xoá gì.
set -uo pipefail
cd "$(dirname "$0")" || exit 1
source ../_lib/check.sh

export AWS_PROFILE="${LAB_PROFILE:-lab-builder}"
export AWS_REGION="us-east-1"
export AWS_DEFAULT_REGION="us-east-1"

check_init "Tuần 9 — Explicit Deny, trần quyền, và những thứ không được phép"

VH=$(need_output vai_van_hanh)         || exit 1
EXTID=$(need_output ma_ngoai)          || exit 1
PK=$(need_output vai_pha_kinh)         || exit 1
KHO=$(need_output kho_du_lieu)         || exit 1
RG=$(need_output ranh_gioi_quyen)      || exit 1
BM_OK=$(need_output duong_bi_mat)      || exit 1
BM_CAM=$(need_output duong_bi_mat_cam) || exit 1

ACCT=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)
KEY_LV="lam-viec/thu.txt"
KEY_BM="bi-mat/thu.txt"

# ---------------------------------------------------------------------------
# Công cụ
# ---------------------------------------------------------------------------

# muon <role-arn> <external-id hoặc rỗng> <giây> -> in "AK SK ST", rỗng nếu hỏng
muon() {
  local args
  args=(--role-arn "$1" --role-session-name "verify-w09-$$" --duration-seconds "$3")
  [ -n "$2" ] && args+=(--external-id "$2")
  aws sts assume-role "${args[@]}" \
    --query 'join(` `,[Credentials.AccessKeyId,Credentials.SecretAccessKey,Credentials.SessionToken])' \
    --output text 2>/dev/null
}

# muon_duoc <role-arn> <external-id> <giây> -> dùng cho assert_cmd_ok/fail
muon_duoc() { [ -n "$(muon "$1" "$2" "$3")" ]; }

# Chạy một lệnh aws dưới danh tính đã mượn.
# `env -u AWS_PROFILE` là bắt buộc: khi AWS_PROFILE được đặt, CLI ưu tiên profile
# và bỏ qua credential trong biến môi trường — bạn sẽ tưởng mình đang test role
# vận hành trong khi thật ra vẫn đang là admin.
nhu() {
  local ak="$1" sk="$2" st="$3"
  shift 3
  env -u AWS_PROFILE \
    AWS_ACCESS_KEY_ID="$ak" AWS_SECRET_ACCESS_KEY="$sk" AWS_SESSION_TOKEN="$st" \
    AWS_REGION=us-east-1 AWS_DEFAULT_REGION=us-east-1 \
    aws "$@"
}

# sim_vai <role-arn> <action> <resource> -> allowed|implicitDeny|explicitDeny
# simulate-principal-policy có tính cả permissions boundary của principal.
sim_vai() {
  aws iam simulate-principal-policy \
    --policy-source-arn "$1" --action-names "$2" --resource-arns "$3" \
    --query 'EvaluationResults[0].EvalDecision' --output text 2>/dev/null || echo LOI_GOI_API
}

# ---------------------------------------------------------------------------
section "1. Mượn danh tính, không cầm khoá (yêu cầu 1 và 2)"
# ---------------------------------------------------------------------------

CRED=$(muon "$VH" "$EXTID" 900)
if [ -n "$CRED" ]; then
  ok "mượn được vai vận hành khi kèm đúng mã ngoài" "phiên 900 giây"
  # shellcheck disable=SC2086
  set -- $CRED
  VH_AK="$1" VH_SK="$2" VH_ST="$3"
else
  fail "mượn được vai vận hành khi kèm đúng mã ngoài" \
    "sts:AssumeRole thành công" \
    "bị từ chối — trust policy chưa cho danh tính đang chạy lab mượn, hoặc điều kiện ExternalId sai"
  VH_AK="" VH_SK="" VH_ST=""
fi

# NEGATIVE — thiếu mã ngoài
assert_cmd_fail "mượn mà KHÔNG kèm mã ngoài thì bị từ chối" muon_duoc "$VH" "" 900

# NEGATIVE — sai mã ngoài
assert_cmd_fail "mượn với mã ngoài SAI thì bị từ chối" muon_duoc "$VH" "ma-ngoai-bia-dat-$$" 900

# NEGATIVE — phiên không được sống quá 1 giờ
assert_cmd_fail "xin phiên 2 giờ thì bị từ chối" muon_duoc "$VH" "$EXTID" 7200

MAXSD=$(aws iam get-role --role-name "${VH##*/}" --query 'Role.MaxSessionDuration' --output text 2>/dev/null)
if [ -n "$MAXSD" ] && [ "$MAXSD" -le 3600 ] 2>/dev/null; then
  ok "trần thời gian một phiên không quá 3600 giây" "${MAXSD}s"
else
  fail "trần thời gian một phiên không quá 3600 giây" "<= 3600" "${MAXSD:-<không đọc được>}"
fi

# ---------------------------------------------------------------------------
section "2. Vận hành viên làm đúng việc của mình, không hơn (yêu cầu 3)"
# ---------------------------------------------------------------------------

if [ -n "$VH_AK" ]; then
  assert_cmd_ok "vận hành viên đọc được khu làm việc" \
    nhu "$VH_AK" "$VH_SK" "$VH_ST" s3api get-object --bucket "$KHO" --key "$KEY_LV" /dev/null

  # NEGATIVE — không được nhìn thấy danh tính khác trong account
  assert_cmd_fail "vận hành viên KHÔNG liệt kê được danh tính trong account" \
    nhu "$VH_AK" "$VH_SK" "$VH_ST" iam list-users

  # NEGATIVE — không được nhìn thấy hạ tầng máy chủ
  assert_cmd_fail "vận hành viên KHÔNG xem được tài nguyên máy chủ" \
    nhu "$VH_AK" "$VH_SK" "$VH_ST" ec2 describe-instances --max-items 1

  # NEGATIVE — không được liệt kê toàn bộ kho dữ liệu của công ty
  assert_cmd_fail "vận hành viên KHÔNG liệt kê được mọi kho dữ liệu" \
    nhu "$VH_AK" "$VH_SK" "$VH_ST" s3api list-buckets
else
  fail "chạy được nhóm check 2" "mượn được vai vận hành ở nhóm 1" "chưa mượn được — bỏ qua nhóm này"
fi

# Hành động GHI: hỏi Policy Simulator thay vì gọi thật, để không tạo ra rác.
assert_eq "vận hành viên ghi được vào khu làm việc" "allowed" \
  "$(sim_vai "$VH" s3:PutObject "arn:aws:s3:::$KHO/lam-viec/bao-cao.txt")"

assert_ne "vận hành viên KHÔNG tạo được danh tính mới" "allowed" \
  "$(sim_vai "$VH" iam:CreateUser "arn:aws:iam::$ACCT:user/nguoi-la")"

# ---------------------------------------------------------------------------
section "3. Explicit Deny thắng mọi Allow (yêu cầu 4 và 5)"
# ---------------------------------------------------------------------------

# NEGATIVE — vận hành viên không đọc được bảng lương
if [ -n "$VH_AK" ]; then
  assert_cmd_fail "vận hành viên KHÔNG đọc được bảng lương" \
    nhu "$VH_AK" "$VH_SK" "$VH_ST" s3api get-object --bucket "$KHO" --key "$KEY_BM" /dev/null
fi

# NEGATIVE — và cả danh tính đang chạy lab cũng không, dù nó có AdministratorAccess.
# Đây là check dạy nhiều nhất trong lab: identity policy nói "được", resource
# policy nói "không", và "không" thắng.
assert_cmd_fail "danh tính admin đang chạy lab cũng KHÔNG đọc được bảng lương" \
  aws s3api get-object --bucket "$KHO" --key "$KEY_BM" /dev/null

# Đối chứng: Deny phải HẸP. Cùng danh tính đó vẫn đọc được khu làm việc.
assert_cmd_ok "cùng danh tính đó vẫn đọc được khu làm việc" \
  aws s3api get-object --bucket "$KHO" --key "$KEY_LV" /dev/null

# Cửa phá kính
PK_CRED=$(muon "$PK" "" 900)
if [ -n "$PK_CRED" ]; then
  # shellcheck disable=SC2086
  set -- $PK_CRED
  assert_cmd_ok "vai phá kính đọc được bảng lương" \
    nhu "$1" "$2" "$3" s3api get-object --bucket "$KHO" --key "$KEY_BM" /dev/null
else
  fail "mượn được vai phá kính" "sts:AssumeRole thành công" \
    "bị từ chối — trust policy của vai phá kính chưa cho danh tính đang chạy lab mượn"
fi

# ---------------------------------------------------------------------------
section "4. Bí mật lưu đúng chỗ (yêu cầu 6)"
# ---------------------------------------------------------------------------

LOAI=$(aws ssm get-parameter --name "$BM_OK" --query 'Parameter.Type' --output text 2>/dev/null)
assert_eq "bí mật được lưu ở dạng mã hoá" "SecureString" "${LOAI:-<không tìm thấy tham số>}"

if [ -n "$VH_AK" ]; then
  assert_cmd_ok "vận hành viên đọc và giải mã được bí mật của mình" \
    nhu "$VH_AK" "$VH_SK" "$VH_ST" ssm get-parameter --name "$BM_OK" --with-decryption

  # NEGATIVE — bí mật của đội khác thì không
  assert_cmd_fail "vận hành viên KHÔNG đọc được bí mật của đội khác" \
    nhu "$VH_AK" "$VH_SK" "$VH_ST" ssm get-parameter --name "$BM_CAM" --with-decryption
fi

# ---------------------------------------------------------------------------
section "5. Trần quyền bạn tự viết (yêu cầu 7)"
# ---------------------------------------------------------------------------

# Lấy nội dung policy bạn viết, từ IAM chứ không từ file .tf.
VER=$(aws iam get-policy --policy-arn "$RG" --query 'Policy.DefaultVersionId' --output text 2>/dev/null)
if [ -z "$VER" ] || [ "$VER" = "None" ]; then
  fail "ranh_gioi_quyen trỏ tới một policy có thật" \
    "một customer managed policy đọc được bằng iam:GetPolicy" \
    "$RG — không tìm thấy"
  BDOC=""
else
  ok "ranh_gioi_quyen là một policy có thật trong IAM" "$RG (version $VER)"
  BDOC=$(aws iam get-policy-version --policy-arn "$RG" --version-id "$VER" --output json 2>/dev/null |
    python3 -c '
import sys, json, urllib.parse
try:
    d = json.load(sys.stdin)["PolicyVersion"]["Document"]
except Exception:
    sys.exit(1)
if isinstance(d, str):
    d = json.loads(urllib.parse.unquote(d))
print(json.dumps(d, separators=(",", ":")))
' 2>/dev/null)
fi

# Identity policy giả định: rộng nhất có thể. Đây chính là kịch bản "ba tháng nữa
# có kỹ sư mới gắn AdministratorAccess cho nhanh" trong đề bài.
ADMIN_DOC='{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Action":"*","Resource":"*"}]}'

# sim_tran <action> <resource> -> quyết định khi quyền admin bị bóp bởi trần của bạn
sim_tran() {
  aws iam simulate-custom-policy \
    --policy-input-list "$ADMIN_DOC" \
    --permissions-boundary-policy-input-list "$BDOC" \
    --action-names "$1" --resource-arns "$2" \
    --query 'EvaluationResults[0].EvalDecision' --output text 2>/dev/null || echo LOI_GOI_API
}

if [ -n "$BDOC" ]; then
  echo "  (giả định: có người vừa gắn AdministratorAccess vào vai vận hành)"

  assert_eq "trần vẫn cho ghi vào khu làm việc" "allowed" \
    "$(sim_tran s3:PutObject "arn:aws:s3:::$KHO/lam-viec/x.txt")"

  assert_eq "trần vẫn cho đọc khu làm việc" "allowed" \
    "$(sim_tran s3:GetObject "arn:aws:s3:::$KHO/lam-viec/x.txt")"

  # NEGATIVE — bốn đường thoát phải bị bịt
  assert_ne "trần chặn tạo danh tính mới" "allowed" \
    "$(sim_tran iam:CreateUser "arn:aws:iam::$ACCT:user/nguoi-la")"

  assert_ne "trần chặn khởi động máy chủ" "allowed" \
    "$(sim_tran ec2:RunInstances "arn:aws:ec2:us-east-1:$ACCT:instance/*")"

  assert_ne "trần chặn đọc kho dữ liệu khác" "allowed" \
    "$(sim_tran s3:GetObject "arn:aws:s3:::kho-cua-cong-ty-khac/luong.csv")"

  assert_ne "trần chặn việc tự tháo trần" "allowed" \
    "$(sim_tran iam:DeleteRolePermissionsBoundary "$VH")"

  assert_ne "trần chặn việc tự sửa nội dung trần" "allowed" \
    "$(sim_tran iam:CreatePolicyVersion "$RG")"
fi

# Vai vận hành có thật sự mang một trần quyền ở tầng AWS không?
PB=$(aws iam get-role --role-name "${VH##*/}" \
  --query 'Role.PermissionsBoundary.PermissionsBoundaryArn' --output text 2>/dev/null)
assert_ne "vai vận hành có gắn permission boundary ở tầng AWS" "None" "${PB:-None}"

# ---------------------------------------------------------------------------
if summary; then
  cat <<'EOF'

Hai câu tự hỏi trước khi đọc DOI-CHIEU.md:

  1. Check "danh tính admin cũng KHÔNG đọc được bảng lương" vừa xanh. Vậy nếu
     account của bạn nằm trong AWS Organizations và ai đó viết một SCP cho phép
     s3:* — bảng lương có bị lộ không? Vì sao?
     (Gợi ý: SCP là trần hay là cấp quyền?)

  2. Trần quyền bạn viết chặn được iam:CreateUser. Nhưng nếu vai vận hành được
     phép gọi sts:AssumeRole sang một role KHÁC không có trần — thì trần của bạn
     còn nghĩa lý gì không? Bạn đã chặn đường đó chưa, hay chỉ chưa ai thử?
EOF
fi
