#!/usr/bin/env bash
# Trọng tài của lab tuần 6.
#
# Không đọc một dòng .tf nào. Nó gọi HTTP THẬT vào API của bạn từ máy này, đúng
# như một client bên ngoài, rồi hỏi thẳng AWS về danh tính và cấu hình.
#
# Chín check phủ định là phần đáng giá nhất của lab, và chúng chia hai nhóm:
#
#   HỢP ĐỒNG HTTP  — input sai phải trả mã lỗi ĐÚNG, không phải 500:
#     thiếu url -> 400 · url sai giao thức -> 400 · thân không phải JSON -> 400
#     mã không tồn tại -> 404 · phương thức không khai báo -> 404/405
#
#   QUYỀN TỐI THIỂU — hỏi thẳng AWS bằng policy simulator:
#     đọc cả bảng -> Deny · xoá bảng -> Deny · ghi bảng khác -> Deny
#     đọc kho object -> Deny
#
# Một lab chỉ có check "API trả về 201" thì một hàm chạy bằng quyền admin và
# nuốt mọi lỗi thành 500 cũng xanh y hệt.
#
# Script này CÓ GHI: nó tạo vài mã ngắn qua chính API của bạn — không gọi thì
# không chứng minh được gì. Nó không sửa cấu hình nào, không xoá gì, và chạy
# lại bao nhiêu lần cũng cho cùng kết quả.
set -uo pipefail
cd "$(dirname "$0")" || exit 1
source ../_lib/check.sh

export AWS_PROFILE="${LAB_PROFILE:-lab-builder}"
export AWS_REGION="us-east-1"
export AWS_DEFAULT_REGION="us-east-1"

check_init "Tuần 6 — API không có máy chủ nào"

API=$(need_output api_url)          || exit 1
API_ID=$(need_output api_id)        || exit 1
DUONG=$(need_output duong_dan_tao)  || exit 1
HAM=$(need_output function_name)    || exit 1
ROLE=$(need_output role_arn)        || exit 1
BANG=$(need_output table_name)      || exit 1
CHI_PHI=$(need_output chi_phi)      || exit 1

ACCT=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)
ARN_BANG="arn:aws:dynamodb:us-east-1:${ACCT}:table/${BANG}"
ARN_BANG_KHAC="arn:aws:dynamodb:us-east-1:${ACCT}:table/self-w06-luong-nhan-vien"
ROLE_TEN="${ROLE##*/}"

echo
echo "  chi_phi = $CHI_PHI"

# --- tiện ích ---------------------------------------------------------------

# post_tao <thân gửi đi> — đặt hai biến: MA_HTTP (mã trả về) và THAN_TRA (thân)
MA_HTTP=""
THAN_TRA=""
post_tao() {
  local tam
  tam=$(mktemp)
  MA_HTTP=$(curl -s -m 25 -o "$tam" -w '%{http_code}' \
    -X POST "${API}${DUONG}" \
    -H 'Content-Type: application/json' \
    --data-raw "$1" 2>/dev/null)
  THAN_TRA=$(tr -d '\r\n' <"$tam")
  rm -f "$tam"
}

# truong_json <thân> <tên trường> -> giá trị, rỗng nếu không có
truong_json() {
  printf '%s' "$1" | python3 -c '
import sys, json
try:
    d = json.load(sys.stdin)
except Exception:
    raise SystemExit
v = d.get(sys.argv[1]) if isinstance(d, dict) else None
print(v if v is not None else "")
' "$2" 2>/dev/null
}

# header_cua <url> -> toàn bộ header phản hồi, KHÔNG theo redirect
header_cua() {
  curl -s -m 25 -o /dev/null -D - "$1" 2>/dev/null | tr -d '\r'
}

ma_tu_header() {
  printf '%s\n' "$1" | awk '/^HTTP\//{c=$2} END{print (c==""?"<không phản hồi>":c)}'
}

hdr() {
  printf '%s\n' "$1" | awk -v k="$2:" 'tolower($1)==k {sub(/^[^:]*:[ \t]*/,""); print; exit}'
}

# mo_phong <action> <arn tài nguyên> -> allowed / explicitDeny / implicitDeny
mo_phong() {
  aws iam simulate-principal-policy \
    --policy-source-arn "$ROLE" \
    --action-names "$1" \
    --resource-arns "$2" \
    --query 'EvaluationResults[0].EvalDecision' --output text 2>/dev/null
}

# duoc_phep <mô tả> <action> <arn>
duoc_phep() {
  local mota="$1" kq
  kq=$(mo_phong "$2" "$3")
  if [ "$kq" = "allowed" ]; then
    ok "$mota" "$kq"
  else
    fail "$mota" "allowed" \
      "${kq:-<không gọi được simulator>} trên $3 — hàm của bạn sẽ trả 500 khi chạm tới đây"
  fi
}

# bi_tu_choi <mô tả> <action> <arn> <giải thích khi hỏng>
bi_tu_choi() {
  local mota="PHỦ ĐỊNH — $1" kq
  kq=$(mo_phong "$2" "$3")
  case "$kq" in
  implicitDeny | explicitDeny) ok "$mota" "$kq" ;;
  *) fail "$mota" "implicitDeny hoặc explicitDeny" "${kq:-<không gọi được simulator>} — $4" ;;
  esac
}

DAU="w06-$$-$RANDOM"
URL_GOC="https://example.com/chien-dich/mua-he?utm_source=sms&utm_id=${DAU}"

# ---------------------------------------------------------------------------
section "Hợp đồng output đúng hình dạng"
# ---------------------------------------------------------------------------

case "$API" in
*/) fail "api_url không có dấu / ở cuối" "https://xxx.execute-api.us-east-1.amazonaws.com" "$API" ;;
https://*) ok "api_url là địa chỉ HTTPS, không có dấu / ở cuối" "$API" ;;
*) fail "api_url bắt đầu bằng https://" "https://..." "$API" ;;
esac

case "$DUONG" in
/*) ok "duong_dan_tao bắt đầu bằng dấu /" "$DUONG" ;;
*) fail "duong_dan_tao bắt đầu bằng dấu /" "/rutgon" "$DUONG" ;;
esac

case "$ROLE" in
arn:aws:iam::*:role/*) ok "role_arn là ARN của một IAM role" "$ROLE" ;;
*) fail "role_arn là ARN của một IAM role" "arn:aws:iam::<acct>:role/self-w06-..." "$ROLE" ;;
esac

# ---------------------------------------------------------------------------
section "1. Tạo mã ngắn (yêu cầu 1)"
# ---------------------------------------------------------------------------

post_tao "{\"url\":\"${URL_GOC}\"}"
THAN_TAO="$THAN_TRA"

assert_eq "POST ${DUONG} trả 201" "201" "${MA_HTTP:-<không phản hồi>}"

MA=$(truong_json "$THAN_TAO" ma)
if [ -n "$MA" ]; then
  ok "thân trả về có trường \"ma\"" "$MA"
else
  fail "thân trả về có trường \"ma\"" \
    'JSON có trường "ma" là chuỗi mã ngắn' \
    "$(printf '%.160s' "${THAN_TAO:-<rỗng>}")"
fi

# ---------------------------------------------------------------------------
section "2. Dùng mã ngắn (yêu cầu 2, 3)"
# ---------------------------------------------------------------------------

if [ -z "$MA" ]; then
  fail "GET /{ma} chuyển hướng tới URL gốc" \
    "một mã ngắn để thử" "bước 1 chưa trả về mã nào — bỏ qua phần này"
else
  H=$(header_cua "${API}/${MA}")
  MA_CHUYEN=$(ma_tu_header "$H")
  LOC=$(hdr "$H" location)

  case "$MA_CHUYEN" in
  301 | 302 | 307 | 308) ok "GET /{ma} trả mã chuyển hướng" "$MA_CHUYEN" ;;
  *) fail "GET /{ma} trả mã chuyển hướng" "301 hoặc 302" \
    "$MA_CHUYEN — trả 200 kèm JSON thì trình duyệt không đi đâu cả" ;;
  esac

  assert_eq "header Location đúng bằng URL đã gửi" "$URL_GOC" "${LOC:-<không có header Location>}"

  # Gọi lại lần nữa: dữ liệu phải bền, không nằm trong bộ nhớ tiến trình
  H2=$(header_cua "${API}/${MA}")
  LOC2=$(hdr "$H2" location)
  assert_eq "gọi lại lần hai vẫn ra đúng URL đó" "$URL_GOC" "${LOC2:-<không có header Location>}"

  # ... và bản ghi phải thật sự nằm trong kho dữ liệu, không phải trong RAM
  TIM=$(aws dynamodb scan --table-name "$BANG" --limit 200 --output json 2>/dev/null |
    grep -c "utm_id=${DAU}" 2>/dev/null)
  if [ "${TIM:-0}" -ge 1 ] 2>/dev/null; then
    ok "URL gốc nằm thật trong kho dữ liệu" "tìm thấy trong bảng $BANG"
  else
    fail "URL gốc nằm thật trong kho dữ liệu" \
      "một bản ghi trong $BANG có chứa \"utm_id=${DAU}\"" \
      "không thấy trong 200 bản ghi đầu — hàm đang giữ ánh xạ ở đâu đó khác (biến toàn cục sống sót giữa hai lần gọi ấm là ảo giác, không phải kho dữ liệu)"
  fi
fi

# ---------------------------------------------------------------------------
section "3. Input sai trả mã lỗi ĐÚNG, không phải 500 (yêu cầu 4)"
# ---------------------------------------------------------------------------

# kiem_400 <mô tả> <thân gửi đi>
kiem_400() {
  local mota="PHỦ ĐỊNH — $1" loi
  post_tao "$2"
  loi=$(truong_json "$THAN_TRA" loi)

  if [ "$MA_HTTP" = "400" ] && [ -n "$loi" ]; then
    ok "$mota" "400, loi = $(printf '%.60s' "$loi")"
  elif [ "$MA_HTTP" = "400" ]; then
    fail "$mota" '400 kèm JSON có trường "loi"' \
      "400 nhưng thân không có trường \"loi\": $(printf '%.120s' "${THAN_TRA:-<rỗng>}")"
  elif [ "$MA_HTTP" = "500" ] || [ "$MA_HTTP" = "502" ]; then
    fail "$mota" "400" \
      "$MA_HTTP — code của bạn nổ ở đây. 500 nghĩa là \"tôi không lường trước\"; bọc chỗ đọc input lại và tự trả 400"
  else
    fail "$mota" "400" "${MA_HTTP:-<không phản hồi>}"
  fi
}

kiem_400 "thân thiếu trường url -> 400" '{"khong_phai_url":"https://example.com"}'
kiem_400 "url không phải http/https -> 400" '{"url":"ftp://vi-du.test/tap-tin"}'
kiem_400 "thân không phải JSON hợp lệ -> 400" 'day-khong-phai-json{{'

# ---------------------------------------------------------------------------
section "4. Đường không tồn tại trả 404, không trả 500 (yêu cầu 5, 6)"
# ---------------------------------------------------------------------------

MA_LA="khong-ton-tai-$$-$RANDOM"
H3=$(header_cua "${API}/${MA_LA}")
MA_404=$(ma_tu_header "$H3")
LOC404=$(hdr "$H3" location)

if [ "$MA_404" = "404" ]; then
  ok "PHỦ ĐỊNH — mã ngắn không tồn tại -> 404" "404"
elif [ -n "$LOC404" ]; then
  fail "PHỦ ĐỊNH — mã ngắn không tồn tại -> 404" "404 và KHÔNG có header Location" \
    "$MA_404 kèm Location: $LOC404 — bạn đang chuyển hướng người dùng tới một chỗ không ai kiểm soát"
else
  fail "PHỦ ĐỊNH — mã ngắn không tồn tại -> 404" "404" \
    "$MA_404 — tra không thấy bản ghi là chuyện BÌNH THƯỜNG, không phải lỗi hệ thống"
fi

MA_PT=$(curl -s -m 25 -o /dev/null -w '%{http_code}' -X DELETE "${API}${DUONG}" 2>/dev/null)
case "$MA_PT" in
404 | 405 | 403)
  ok "PHỦ ĐỊNH — phương thức không khai báo -> 404/405" "$MA_PT"
  ;;
*)
  fail "PHỦ ĐỊNH — phương thức không khai báo -> 404/405" "404 hoặc 405" \
    "$MA_PT — DELETE ${DUONG} đang chạy vào code của bạn; khai báo đúng route thay vì bắt tất cả"
  ;;
esac

# ---------------------------------------------------------------------------
section "5. Danh tính chỉ làm được đúng việc của nó (yêu cầu 7)"
# ---------------------------------------------------------------------------

duoc_phep "ghi được một bản ghi vào đúng bảng của mình" dynamodb:PutItem "$ARN_BANG"
duoc_phep "đọc được một bản ghi từ đúng bảng của mình" dynamodb:GetItem "$ARN_BANG"

bi_tu_choi "đọc TOÀN BỘ bảng bị từ chối" dynamodb:Scan "$ARN_BANG" \
  "Scan đọc cả bảng. Một lỗi injection ở tầng trên biến nó thành lệnh trút sạch dữ liệu. Hàm này chỉ cần GetItem và PutItem"
bi_tu_choi "xoá bảng bị từ chối" dynamodb:DeleteTable "$ARN_BANG" \
  "dynamodb:* trên đúng một bảng vẫn KHÔNG phải quyền tối thiểu — nó gồm cả DeleteTable"
bi_tu_choi "ghi vào một bảng KHÁC bị từ chối" dynamodb:PutItem "$ARN_BANG_KHAC" \
  "policy của bạn đang khớp theo tiền tố tên bảng (self-w06-*). Quyền tối thiểu trỏ đúng ARN của một bảng, không trỏ vào một họ tên"
bi_tu_choi "đọc kho object bất kỳ bị từ chối" s3:GetObject "arn:aws:s3:::self-w06-khong-lien-quan/*" \
  "role này chưa bao giờ cần S3. Mỗi action thừa là một cánh cửa mở sẵn cho kẻ vào được sau này"

# ---------------------------------------------------------------------------
section "6. Danh tính mang trần quyền của bộ lab (yêu cầu 8)"
# ---------------------------------------------------------------------------

BOUND=$(aws iam get-role --role-name "$ROLE_TEN" \
  --query 'Role.PermissionsBoundary.PermissionsBoundaryArn' --output text 2>/dev/null)

if [ -n "$BOUND" ] && [ "$BOUND" != "None" ]; then
  assert_contains "role có permission boundary của bộ lab" "labs-self-boundary" "$BOUND"
else
  fail "role có permission boundary của bộ lab" \
    "arn:aws:iam::${ACCT}:policy/labs-self-boundary" \
    "${BOUND:-<không có>} — nếu apply chạy được mà chỗ này rỗng thì bạn đang nhìn nhầm role"
fi

case "$ROLE_TEN" in
self-w06-*) ok "tên role đúng tiền tố của tuần này" "$ROLE_TEN" ;;
*) fail "tên role đúng tiền tố của tuần này" "self-w06-..." \
  "$ROLE_TEN — hôm nay vẫn tạo được, nhưng lần đầu bạn sửa trust policy sẽ ăn AccessDenied nói là do permission boundary" ;;
esac

# ---------------------------------------------------------------------------
section "7. Không thiết bị mạng nào tính tiền theo giờ (yêu cầu 9)"
# ---------------------------------------------------------------------------

VPC_HAM=$(aws lambda get-function-configuration --function-name "$HAM" \
  --query 'VpcConfig.VpcId' --output text 2>/dev/null)
if [ -z "$VPC_HAM" ] || [ "$VPC_HAM" = "None" ]; then
  ok "phần xử lý không nằm trong mạng riêng nào" "không có vpc_config"
else
  fail "phần xử lý không nằm trong mạng riêng nào" \
    "không có vpc_config — hàm gọi DynamoDB qua endpoint công cộng, không cần mạng riêng" \
    "$VPC_HAM — trong VPC thì hàm mất đường ra ngoài, và lối thoát duy nhất là NAT Gateway (\$33/tháng, bị hàng rào chặn) hoặc VPC endpoint"
fi

SO_NAT=$(aws ec2 describe-nat-gateways \
  --filter "Name=tag:lab,Values=w06" "Name=state,Values=pending,available" \
  --query 'length(NatGateways)' --output text 2>/dev/null)
assert_eq "không có NAT Gateway nào mang tag lab=w06" "0" "${SO_NAT:-0}"

SO_DAT=$(aws resourcegroupstaggingapi get-resources \
  --tag-filters "Key=lab,Values=w06" \
  --resource-type-filters elasticloadbalancing rds ec2:instance \
  --query 'length(ResourceTagMappingList)' --output text 2>/dev/null)
assert_eq "không có cân bằng tải / máy chủ / CSDL nào mang tag lab=w06" "0" "${SO_DAT:-0}"

# ---------------------------------------------------------------------------
section "8. Hai cái cầu dao chống hoá đơn (yêu cầu 10, 11)"
# ---------------------------------------------------------------------------

LG="/aws/lambda/${HAM}"
GIU=$(aws logs describe-log-groups --log-group-name-prefix "$LG" \
  --query "logGroups[?logGroupName=='$LG'].retentionInDays | [0]" --output text 2>/dev/null)

if [ -n "$GIU" ] && [ "$GIU" != "None" ] && [ "$GIU" -le 7 ] 2>/dev/null; then
  ok "log có hạn giữ, không quá 7 ngày" "${GIU} ngày"
elif [ "$GIU" = "None" ]; then
  fail "log có hạn giữ, không quá 7 ngày" "1..7 ngày" \
    "chưa đặt hạn — nhóm log này giữ VĨNH VIỄN. Nếu bạn để Lambda tự tạo nó thì Terraform cũng không xoá nó lúc destroy"
else
  fail "log có hạn giữ, không quá 7 ngày" "1..7 ngày" "${GIU:-<không tìm thấy nhóm log $LG>}"
fi

# Trần tốc độ — thử cả HTTP API (apigatewayv2) lẫn REST API (apigateway)
TRAN=$(aws apigatewayv2 get-stages --api-id "$API_ID" \
  --query 'max(Items[].DefaultRouteSettings.ThrottlingRateLimit)' --output text 2>/dev/null)
if [ -z "$TRAN" ] || [ "$TRAN" = "None" ]; then
  TRAN=$(aws apigateway get-stages --rest-api-id "$API_ID" \
    --query 'max(item[].methodSettings.*.throttlingRateLimit[])' --output text 2>/dev/null)
fi

if [ -n "$TRAN" ] && [ "$TRAN" != "None" ] && [ "${TRAN%%.*}" -le 100 ] 2>/dev/null && [ "${TRAN%%.*}" -ge 1 ] 2>/dev/null; then
  ok "API có trần tốc độ, không quá 100 request/giây" "${TRAN} req/s"
else
  fail "API có trần tốc độ, không quá 100 request/giây" \
    "1..100 request/giây trên stage" \
    "${TRAN:-<chưa đặt>} — mặc định của tài khoản là 10.000 req/s. Nhân con số đó với một đêm rồi nhìn lại yêu cầu 11"
fi

BILL=$(aws dynamodb describe-table --table-name "$BANG" \
  --query 'Table.BillingModeSummary.BillingMode' --output text 2>/dev/null)
assert_eq "kho dữ liệu không phát sinh phí khi rảnh" "PAY_PER_REQUEST" "${BILL:-PROVISIONED}"

# ---------------------------------------------------------------------------
section "9. Số đo để bạn ghi lại (không tính điểm)"
# ---------------------------------------------------------------------------

BAT_DAU=$(( ($(date +%s) - 21600) * 1000 ))
INIT=$(aws logs filter-log-events --log-group-name "$LG" \
  --start-time "$BAT_DAU" --filter-pattern '"Init Duration"' \
  --query 'events[].message' --output text 2>/dev/null |
  grep -o 'Init Duration: [0-9.]*' | awk '{print $3}' | sort -g | tail -1)

if [ -n "${INIT:-}" ]; then
  echo "    cold start (Init Duration lớn nhất trong 6 giờ qua) : ${INIT} ms"
else
  echo "    cold start: không có lần khởi tạo nguội nào trong 6 giờ qua."
  echo "                ép một lần bằng cách đổi một biến môi trường của hàm rồi gọi lại."
fi

BO_NHO=$(aws lambda get-function-configuration --function-name "$HAM" \
  --query 'MemorySize' --output text 2>/dev/null)
GOI=$(aws lambda get-function-configuration --function-name "$HAM" \
  --query 'CodeSize' --output text 2>/dev/null)
T_AM=$(curl -s -m 25 -o /dev/null -w '%{time_total}' "${API}/${MA_LA}" 2>/dev/null)

echo "    bộ nhớ cấp cho hàm                                  : ${BO_NHO:-?} MB  (bộ nhớ quyết định cả CPU)"
echo "    kích thước gói triển khai                           : ${GOI:-?} byte"
echo "    độ trễ một lần gọi ấm, đo từ máy này                 : ${T_AM:-?} giây"

# ---------------------------------------------------------------------------
if summary; then
  cat <<'EOF'

Hai câu tự hỏi trước khi đọc DOI-CHIEU.md:

  1. Hai hướng quyền của phần xử lý là hai thứ khác nhau: một cái cho phép NÓ
     gọi kho dữ liệu, một cái cho phép API gọi NÓ. Vẽ hai mũi tên đó ra giấy.
     Nếu bạn xoá cái thứ hai đi, API trả mã gì, và log của hàm có dòng nào không?

  2. API của bạn hiện ai gọi cũng được — kể cả một vòng lặp gọi 100 request/giây
     suốt đêm, đúng bằng trần bạn vừa đặt. Trần đó bảo vệ hoá đơn, nhưng nó
     KHÔNG trả lời câu "ai được phép gọi". Kể ba cơ chế trả lời câu đó, và nói
     cái nào dùng khi client là người dùng đăng nhập, khi client là một hệ thống
     khác, và khi client là một đối tác bên ngoài.
EOF
fi
