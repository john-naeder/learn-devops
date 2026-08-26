#!/usr/bin/env bash
# Trọng tài của lab tuần 4.
#
# Không đọc một dòng .tf nào. Mọi câu hỏi đều hỏi thẳng AWS, hoặc hỏi thẳng
# internet bằng curl như một người dùng ẩn danh thật sự.
#
# Bốn check phủ định là phần đáng giá nhất:
#   - gọi thẳng vào kho lưu trữ  -> phải 403
#   - gọi ẩn danh vào gốc kho    -> phải 403 (không liệt kê được file)
#   - gọi bằng http:// không mã hoá -> phải bị chuyển hướng, không phải nội dung
#   - kho không được tự phục vụ web
# Một lab chỉ có check "tải được file" thì bucket public cũng xanh y hệt.
#
# Chạy lại bao nhiêu lần cũng được. Script này không tạo, không sửa, không xoá gì.
set -uo pipefail
cd "$(dirname "$0")" || exit 1
source ../_lib/check.sh

export AWS_PROFILE="${LAB_PROFILE:-lab-builder}"
export AWS_REGION="us-east-1"
export AWS_DEFAULT_REGION="us-east-1"

check_init "Tuần 4 — Kho đóng, cửa hàng mở: CDN trước một kho đã khoá kín"

CDN=$(need_output cdn_url)                       || exit 1
DUONG=$(need_output duong_dan_trang_chu)         || exit 1
BUCKET=$(need_output bucket_name)                || exit 1
KHO_DOMAIN=$(need_output bucket_regional_domain) || exit 1
MOC=$(need_output chuoi_moc)                     || exit 1
CHI_PHI=$(need_output chi_phi)                   || exit 1

# --- tiện ích ---------------------------------------------------------------

ma_http() {   # ma_http <url> [tham số curl thêm...]
  local u="$1"; shift
  curl -s -m 25 -o /dev/null -w '%{http_code}' "$@" "$u" 2>/dev/null
}

header() {    # header <url> [tham số curl thêm...] -> header đã bỏ \r
  local u="$1"; shift
  curl -s -m 25 -o /dev/null -D - "$@" "$u" 2>/dev/null | tr -d '\r'
}

than() {      # than <url> [tham số curl thêm...]
  local u="$1"; shift
  curl -s -m 25 "$@" "$u" 2>/dev/null
}

lay_header() { # lay_header <chuoi-header> <ten-header>
  printf '%s\n' "$1" | grep -i "^$2:" | head -1 | sed "s/^[^:]*: *//"
}

# ---------------------------------------------------------------------------
section "Hợp đồng output đúng hình dạng"

case "$CDN" in
*/) fail "cdn_url không có dấu / ở cuối" "https://xxx.cloudfront.net" "$CDN" ;;
https://*) ok "cdn_url là địa chỉ HTTPS, không có dấu / ở cuối" "$CDN" ;;
*) fail "cdn_url bắt đầu bằng https://" "https://..." "$CDN" ;;
esac
CDN="${CDN%/}"

case "$DUONG" in
/*) ok "duong_dan_trang_chu bắt đầu bằng dấu /" "$DUONG" ;;
*) fail "duong_dan_trang_chu bắt đầu bằng dấu /" "/index.html" "$DUONG"; DUONG="/$DUONG" ;;
esac

HOST="${CDN#https://}"
URL="${CDN}${DUONG}"
URL_HTTP="http://${HOST}${DUONG}"
KEY="${DUONG#/}"

# Phân phối còn đang triển khai thì mọi check hành vi sẽ đỏ vì lý do không
# liên quan gì tới kiến trúc. Nói trước cho người học, đừng để họ đoán.
DIST=$(aws cloudfront list-distributions \
  --query "DistributionList.Items[?DomainName=='${HOST}'].Id | [0]" \
  --output text 2>/dev/null)
if [ -n "$DIST" ] && [ "$DIST" != "None" ]; then
  TRANG_THAI=$(aws cloudfront get-distribution --id "$DIST" \
    --query 'Distribution.Status' --output text 2>/dev/null)
  if [ "$TRANG_THAI" != "Deployed" ]; then
    echo
    echo "  CẢNH BÁO: phân phối $DIST đang ở trạng thái '$TRANG_THAI', chưa 'Deployed'."
    echo "  Chờ thêm vài phút rồi chạy lại — các check dưới đây sẽ đỏ oan."
    echo
  fi
fi

# ---------------------------------------------------------------------------
section "Địa chỉ công khai phục vụ đúng nội dung (yêu cầu 1)"

MA=$(ma_http "$URL")
assert_eq "gọi HTTPS vào trang chủ trả về 200" "200" "${MA:-khong-ket-noi-duoc}"

NOI_DUNG=$(than "$URL")
if printf '%s' "$NOI_DUNG" | grep -qF "$MOC"; then
  ok "nội dung trả về đúng là trang của bạn" "tìm thấy chuỗi mốc $MOC"
else
  fail "nội dung trả về đúng là trang của bạn" \
       "thân response chứa chuỗi mốc \"$MOC\"" \
       "$(printf '%s' "$NOI_DUNG" | tr -d '\n' | head -c 90)"
fi

CO_CHU=$(printf '%s' "$NOI_DUNG" | wc -c)
if [ "${CO_CHU:-0}" -gt 1024 ]; then
  ok "trang chủ dài hơn 1 KB (điều kiện để CDN chịu nén)" "${CO_CHU} byte"
else
  fail "trang chủ dài hơn 1 KB" \
       "> 1024 byte — dưới ngưỡng này CDN KHÔNG BAO GIỜ nén, và yêu cầu 5 sẽ đỏ mãi" \
       "${CO_CHU:-0} byte"
fi

# ---------------------------------------------------------------------------
section "PHỦ ĐỊNH — kho lưu trữ không cho ai vào thẳng (yêu cầu 2, 3)"

MA_KHO=$(ma_http "https://${KHO_DOMAIN}${DUONG}")
if [ "$MA_KHO" = "403" ]; then
  ok "cùng file đó, gọi THẲNG vào kho thì bị từ chối" "HTTP 403"
elif [ "$MA_KHO" = "404" ]; then
  fail "cùng file đó, gọi THẲNG vào kho thì bị từ chối" \
       "HTTP 403 (bị chặn)" \
       "HTTP 404 — kho trả lời được, chỉ là không có file ở đường dẫn này. Kho vẫn đang mở"
else
  fail "cùng file đó, gọi THẲNG vào kho thì bị từ chối" \
       "HTTP 403" "HTTP ${MA_KHO:-khong-ket-noi-duoc}"
fi

MA_GOC=$(ma_http "https://${KHO_DOMAIN}/")
if [ "$MA_GOC" = "403" ]; then
  ok "người lạ không liệt kê được danh sách file trong kho" "HTTP 403"
else
  fail "người lạ không liệt kê được danh sách file trong kho" \
       "HTTP 403" "HTTP ${MA_GOC:-khong-ket-noi-duoc} — cấu trúc thư mục cũng là thông tin"
fi

BPA=$(aws s3api get-public-access-block --bucket "$BUCKET" \
  --query 'PublicAccessBlockConfiguration.[BlockPublicAcls,IgnorePublicAcls,BlockPublicPolicy,RestrictPublicBuckets]' \
  --output text 2>/dev/null | tr -s '[:space:]' ' ' | sed 's/ $//')
assert_eq "cả bốn khoá chặn public đều bật" "True True True True" "${BPA:-<không đọc được>}"

CONG_KHAI=$(aws s3api get-bucket-policy-status --bucket "$BUCKET" \
  --query 'PolicyStatus.IsPublic' --output text 2>/dev/null)
assert_eq "AWS tự đánh giá resource policy của kho là KHÔNG public" "False" "${CONG_KHAI:-khong-doc-duoc}"

SO_ACL_MO=$(aws s3api get-bucket-acl --bucket "$BUCKET" \
  --query "length(Grants[?Grantee.URI!=null && (contains(Grantee.URI, 'AllUsers') || contains(Grantee.URI, 'AuthenticatedUsers'))])" \
  --output text 2>/dev/null)
assert_eq "không quyền ACL nào cấp cho AllUsers/AuthenticatedUsers" "0" "${SO_ACL_MO:-loi}"

assert_cmd_fail "PHỦ ĐỊNH: kho không tự phục vụ web qua endpoint website" \
  aws s3api get-bucket-website --bucket "$BUCKET"

# ---------------------------------------------------------------------------
section "PHỦ ĐỊNH — đường truyền không mã hoá bị chặn (yêu cầu 4)"

MA_HTTP=$(ma_http "$URL_HTTP")
case "${MA_HTTP:-0}" in
301 | 302 | 307 | 308)
  H=$(header "$URL_HTTP")
  DICH=$(lay_header "$H" location)
  ok "gọi bằng http:// bị chuyển hướng, không nhận nội dung" "HTTP $MA_HTTP -> ${DICH:-<không có Location>}"
  ;;
403)
  ok "gọi bằng http:// bị từ chối thẳng" "HTTP 403 (chặt hơn chuyển hướng — cũng đạt)"
  ;;
200)
  fail "gọi bằng http:// không được trả nội dung" \
       "301/302/307/308 (chuyển hướng) hoặc 403" \
       "HTTP 200 — nội dung đi qua đường không mã hoá"
  ;;
*)
  fail "gọi bằng http:// bị chuyển hướng hoặc từ chối" \
       "301/302/307/308 hoặc 403" "HTTP ${MA_HTTP:-khong-ket-noi-duoc}"
  ;;
esac

# ---------------------------------------------------------------------------
section "Nén và bộ nhớ đệm ở biên (yêu cầu 5, 6)"

H_NEN=$(header "$URL" -H 'Accept-Encoding: gzip, br')
NEN=$(lay_header "$H_NEN" content-encoding)
case "$NEN" in
*gzip* | *br*)
  ok "nội dung được nén trước khi truyền đi" "content-encoding: $NEN"
  ;;
*)
  CT=$(lay_header "$H_NEN" content-type)
  fail "nội dung được nén trước khi truyền đi" \
       "header content-encoding: gzip hoặc br" \
       "không có header đó. content-type hiện tại: ${CT:-<không có>} — nếu nó là binary/octet-stream thì CDN không coi file này là nén được"
  ;;
esac

TRUNG=""
for _ in 1 2 3 4 5 6; do
  H_CACHE=$(header "$URL")
  XC=$(lay_header "$H_CACHE" x-cache)
  case "$XC" in
  *Hit*)
    TRUNG="$XC"
    break
    ;;
  esac
  sleep 2
done
if [ -n "$TRUNG" ]; then
  ok "lần gọi sau được phục vụ từ bộ nhớ đệm ở biên" "x-cache: $TRUNG"
else
  XC=$(lay_header "$(header "$URL")" x-cache)
  fail "lần gọi sau được phục vụ từ bộ nhớ đệm ở biên" \
       "x-cache chứa \"Hit from cloudfront\" sau vài lần gọi" \
       "${XC:-<không có header x-cache>} — kiểm tra TTL của cache behavior, hoặc header Cache-Control mà origin gửi lên"
fi

# ---------------------------------------------------------------------------
section "Vòng đời dữ liệu (yêu cầu 7, 8, 9)"

VS=$(aws s3api get-bucket-versioning --bucket "$BUCKET" --query 'Status' --output text 2>/dev/null)
assert_eq "kho giữ lại bản cũ khi bị ghi đè" "Enabled" "${VS:-Chua-bat}"

VID=$(aws s3api list-object-versions --bucket "$BUCKET" --prefix "$KEY" \
  --query "Versions[?Key=='${KEY}'] | [0].VersionId" --output text 2>/dev/null)
if [ -n "$VID" ] && [ "$VID" != "None" ]; then
  assert_cmd_ok "đọc lại được một phiên bản CỤ THỂ theo VersionId" \
    aws s3api head-object --bucket "$BUCKET" --key "$KEY" --version-id "$VID"
else
  fail "đọc lại được một phiên bản CỤ THỂ theo VersionId" \
       "trang chủ có ít nhất một version có VersionId" \
       "không tìm thấy version nào cho key \"$KEY\" (versioning bật SAU khi upload thì version đầu tiên mang id \"null\")"
fi

SO_RULE=$(aws s3api get-bucket-lifecycle-configuration --bucket "$BUCKET" \
  --query "length(Rules[?Status=='Enabled' && (NoncurrentVersionExpiration!=null || NoncurrentVersionTransitions!=null)])" \
  --output text 2>/dev/null)
if [ "${SO_RULE:-0}" != "0" ] && [ -n "${SO_RULE:-}" ] && [ "${SO_RULE}" != "None" ]; then
  ok "có quy tắc vòng đời đang bật, xử lý bản KHÔNG còn hiện hành" "$SO_RULE quy tắc"
else
  fail "có quy tắc vòng đời đang bật, xử lý bản KHÔNG còn hiện hành" \
       ">= 1 rule Status=Enabled có NoncurrentVersionExpiration hoặc NoncurrentVersionTransitions" \
       "${SO_RULE:-0} — quy tắc chỉ xử lý bản hiện hành KHÔNG dọn được 4 GB bản nháp cũ của đội tài chính"
fi

ALG=$(aws s3api get-bucket-encryption --bucket "$BUCKET" \
  --query 'ServerSideEncryptionConfiguration.Rules[0].ApplyServerSideEncryptionByDefault.SSEAlgorithm' \
  --output text 2>/dev/null)
case "$ALG" in
AES256 | aws:kms | aws:kms:dsse) ok "dữ liệu được mã hoá khi lưu" "SSEAlgorithm=$ALG" ;;
*) fail "dữ liệu được mã hoá khi lưu" "AES256 hoặc aws:kms" "${ALG:-khong-doc-duoc}" ;;
esac

# ---------------------------------------------------------------------------
section "Thông tin (không chấm, nhưng đáng nhìn)"

echo "  chi phí bạn khai   : $CHI_PHI"

if [ -n "$DIST" ] && [ "$DIST" != "None" ]; then
  read -r PC ORIGIN <<<"$(aws cloudfront get-distribution-config --id "$DIST" \
    --query 'DistributionConfig.[PriceClass,Origins.Items[0].DomainName]' \
    --output text 2>/dev/null)"
  echo "  phân phối          : $DIST  ($PC)"
  echo "  origin             : $ORIGIN"
  case "$ORIGIN" in
  *s3-website*) echo "                       ^ đây là endpoint WEBSITE, không phải endpoint REST — xem HINTS lỗi 3" ;;
  esac
fi

SO_CU=$(aws s3api list-object-versions --bucket "$BUCKET" \
  --query 'length(Versions[?IsLatest==`false`] || `[]`)' --output text 2>/dev/null)
SO_XOA=$(aws s3api list-object-versions --bucket "$BUCKET" \
  --query 'length(DeleteMarkers || `[]`)' --output text 2>/dev/null)
echo "  version cũ đang giữ: ${SO_CU:-0}   |   delete marker: ${SO_XOA:-0}"
echo "                       (cả hai đều TÍNH TIỀN lưu trữ, và cả hai đều vô hình với 'aws s3 ls')"

PRIN=$(aws s3api get-bucket-policy --bucket "$BUCKET" --query Policy --output text 2>/dev/null |
  grep -o '"Service"[^}]*' | head -1)
echo "  principal trong resource policy của kho: ${PRIN:-<không phải Service — bạn dùng cơ chế nào?>}"

summary

cat <<'EOF'

Hai câu tự hỏi trước khi mở DOI-CHIEU.md:

  1. Resource policy của kho cho phép "dịch vụ CDN" đọc. Trên đời có hàng triệu
     phân phối CDN. Điều gì trong policy của bạn ngăn phân phối của MỘT NGƯỜI
     LẠ trỏ vào kho của bạn và đọc sạch? Nếu bạn không chỉ ra được đúng một
     dòng, thì kho của bạn đang mở cho cả thế giới qua một cửa sau — và lỗ hổng
     đó có tên riêng trong đề thi.

  2. Bạn vừa sửa nội dung trang nhưng CDN vẫn trả bản cũ. Có hai cách xử lý:
     một cách tốn tiền sau 1.000 lần mỗi tháng, một cách miễn phí vĩnh viễn.
     Cách miễn phí là gì, vì sao nó miễn phí, và vì sao mọi công cụ build hiện
     đại đều làm đúng cách đó mà không ai gọi tên nó ra?
EOF
