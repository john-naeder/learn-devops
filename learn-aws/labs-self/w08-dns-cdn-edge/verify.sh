#!/usr/bin/env bash
# Trọng tài của lab tuần 8.
#
# Không đọc một dòng .tf nào, và cũng gần như không dùng AWS API để hỏi cấu
# hình. Lý do: cấu hình đúng mà hành vi sai thì vẫn là sai. Cách duy nhất biết
# một request có được phục vụ từ biên hay không là **gọi thật rồi đọc header
# phản hồi** — đúng như cách bạn debug CDN trong đời thật.
#
# Header quyết định mọi thứ ở đây là `x-cache`:
#   Miss from cloudfront        -> đi tới tận kho
#   Hit from cloudfront         -> lấy từ bản đã lưu ở biên
#   RefreshHit from cloudfront  -> có bản lưu, biên hỏi kho xem còn mới không
#
# Script này CHỈ ĐỌC. Không tạo, không sửa, không xoá gì.
set -uo pipefail
cd "$(dirname "$0")" || exit 1
source ../_lib/check.sh

export AWS_PROFILE="${LAB_PROFILE:-lab-builder}"
export AWS_REGION="us-east-1"
export AWS_DEFAULT_REGION="us-east-1"

check_init "Tuần 8 — Cùng một kho, ba hành vi biên"

BIEN=$(need_output dia_chi_bien) || exit 1
KHO=$(need_output kho_luu_tru)   || exit 1

# Output tuỳ chọn: đọc thẳng, không qua need_output, vì thiếu chúng KHÔNG phải lỗi.
TEN_MIEN=$(terraform -chdir=terraform output -raw ten_mien 2>/dev/null)
VUNG_DNS=$(terraform -chdir=terraform output -raw vung_dns 2>/dev/null)

# Gỡ https:// và dấu / thừa nếu người học lỡ khai kèm.
BIEN=${BIEN#https://}
BIEN=${BIEN#http://}
BIEN=${BIEN%/}

# ---------------------------------------------------------------------------
# Công cụ
# ---------------------------------------------------------------------------

# goi <url> -> in toàn bộ header phản hồi (không theo redirect)
goi() { curl -sS -o /dev/null -D - --max-time 25 "$1" 2>/dev/null | tr -d '\r'; }

# ma <blob header> -> mã HTTP
ma() { printf '%s\n' "$1" | awk '/^HTTP\//{c=$2} END{print (c==""?"<không phản hồi>":c)}'; }

# hdr <blob header> <tên viết thường> -> giá trị header
hdr() {
  printf '%s\n' "$1" | awk -v k="$2:" 'tolower($1)==k {sub(/^[^:]*:[ \t]*/,""); print; exit}'
}

# la_hit <giá trị x-cache> -> 0 nếu là bản lấy từ biên
la_hit() { case "$1" in *Hit*) return 0 ;; *) return 1 ;; esac; }

# nung <url> <số lần> — gọi vài lần để biên kịp lưu bản sao, in x-cache cuối
nung() {
  local u="$1" n="$2" i h x=""
  for i in $(seq 1 "$n"); do
    h=$(goi "$u")
    x=$(hdr "$h" x-cache)
    la_hit "$x" && break
    sleep 2
  done
  printf '%s' "${x:-<không có header x-cache>}"
}

R1="$$$RANDOM"
R2="$$$RANDOM$RANDOM"

echo
echo "  điểm biên: https://$BIEN"
echo "  kho gốc  : $KHO"

# ---------------------------------------------------------------------------
section "1. Đường vào (yêu cầu 1 và 2)"
# ---------------------------------------------------------------------------

H=$(goi "https://$BIEN/tinh/thu.txt")
assert_eq "biên phục vụ /tinh/thu.txt qua HTTPS" "200" "$(ma "$H")"

H=$(goi "https://$BIEN/nguoidung/thu.txt?u=khoidong")
assert_eq "biên phục vụ /nguoidung/thu.txt" "200" "$(ma "$H")"

H=$(goi "https://$BIEN/api/thu.txt")
assert_eq "biên phục vụ /api/thu.txt" "200" "$(ma "$H")"

# NEGATIVE — http:// không được trả nội dung
H=$(goi "http://$BIEN/tinh/thu.txt")
MA_HTTP=$(ma "$H")
case "$MA_HTTP" in
30*) ok "gọi bằng http:// bị đẩy sang https" "$MA_HTTP $(hdr "$H" location)" ;;
*) fail "gọi bằng http:// bị đẩy sang https" "301 hoặc 302" "$MA_HTTP — biên đang phục vụ nội dung qua HTTP" ;;
esac

# NEGATIVE — vào thẳng kho phải bị từ chối
MA_KHO=$(ma "$(goi "https://$KHO.s3.us-east-1.amazonaws.com/tinh/thu.txt")")
case "$MA_KHO" in
403 | 404) ok "vào thẳng kho lưu trữ bị từ chối" "$MA_KHO" ;;
200) fail "vào thẳng kho lưu trữ bị từ chối" "403" "200 — kho đang mở ra internet, tầng biên vô nghĩa" ;;
*) fail "vào thẳng kho lưu trữ bị từ chối" "403" "$MA_KHO" ;;
esac

# NEGATIVE — bốn công tắc chặn public phải bật hết
PAB=$(aws s3api get-public-access-block --bucket "$KHO" \
  --query 'join(`,`,[to_string(PublicAccessBlockConfiguration.BlockPublicAcls),to_string(PublicAccessBlockConfiguration.IgnorePublicAcls),to_string(PublicAccessBlockConfiguration.BlockPublicPolicy),to_string(PublicAccessBlockConfiguration.RestrictPublicBuckets)])' \
  --output text 2>/dev/null)
assert_eq "kho bật đủ 4 công tắc chặn public" "true,true,true,true" "${PAB:-<chưa bật Block Public Access>}"

# ---------------------------------------------------------------------------
section "2. /tinh/* — query string KHÔNG được tách bản cache (yêu cầu 3)"
# ---------------------------------------------------------------------------

X=$(nung "https://$BIEN/tinh/thu.txt?v=$R1" 3)
if la_hit "$X"; then
  ok "gọi lại cùng URL thì được phục vụ từ biên" "$X"
else
  fail "gọi lại cùng URL thì được phục vụ từ biên" "x-cache chứa Hit sau 3 lần gọi" \
    "$X — đường /tinh/* đang không lưu cache"
fi

# Đây là check quan trọng nhất của mục: đổi query string sang một giá trị CHƯA
# BAO GIỜ xuất hiện. Nếu query string nằm ngoài cache key thì nó vẫn phải Hit
# ngay lần gọi ĐẦU TIÊN.
X=$(hdr "$(goi "https://$BIEN/tinh/thu.txt?v=$R2")" x-cache)
if la_hit "$X"; then
  ok "?v= khác vẫn dùng chung bản cache cũ" "$X"
else
  fail "?v= khác vẫn dùng chung bản cache cũ" "Hit ngay lần gọi đầu" \
    "$X — query string đang nằm trong cache key, mỗi lần build frontend là một bản cache mới"
fi

# ---------------------------------------------------------------------------
section "3. /nguoidung/* — query string PHẢI tách bản cache (yêu cầu 3)"
# ---------------------------------------------------------------------------

X=$(nung "https://$BIEN/nguoidung/thu.txt?u=alice-$R1" 3)
if la_hit "$X"; then
  ok "cùng một ?u= thì lần sau lấy từ biên" "$X"
else
  fail "cùng một ?u= thì lần sau lấy từ biên" "x-cache chứa Hit sau 3 lần gọi" \
    "$X — đường /nguoidung/* đang không lưu gì, người dùng cũ quay lại vẫn phải chờ"
fi

# NEGATIVE — người dùng khác KHÔNG được nhận bản cache của người trước.
# Đây chính là sự cố "khách nhìn thấy tên người khác" trong đề bài.
X=$(hdr "$(goi "https://$BIEN/nguoidung/thu.txt?u=bob-$R2")" x-cache)
if la_hit "$X"; then
  fail "?u= khác KHÔNG được dùng bản cache của người trước" \
    "Miss (bản riêng cho từng người dùng)" \
    "$X — hai người dùng đang chia nhau một bản cache: đây là rò rỉ dữ liệu, không phải lỗi hiệu năng"
else
  ok "?u= khác được coi là một bản riêng" "$X"
fi

# ---------------------------------------------------------------------------
section "4. /api/* — không bao giờ phục vụ từ bản đã lưu (yêu cầu 3)"
# ---------------------------------------------------------------------------

X1=$(hdr "$(goi "https://$BIEN/api/thu.txt")" x-cache)
sleep 1
X2=$(hdr "$(goi "https://$BIEN/api/thu.txt")" x-cache)

# NEGATIVE — hai lần gọi liên tiếp, lần thứ hai vẫn phải đi tới tận kho
if la_hit "$X2"; then
  fail "/api/* không bao giờ được phục vụ từ biên" "Miss ở cả hai lần gọi" \
    "lần 1: $X1 · lần 2: $X2 — API đang trả dữ liệu cũ"
else
  ok "/api/* luôn đi tới tận kho" "lần 1: ${X1:-?} · lần 2: ${X2:-?}"
fi

# ---------------------------------------------------------------------------
section "5. Header bảo mật do biên chèn (yêu cầu 4)"
# ---------------------------------------------------------------------------

NOSNIFF=$(hdr "$(goi "https://$BIEN/tinh/thu.txt")" x-content-type-options)
assert_eq "phản hồi qua biên mang x-content-type-options" "nosniff" "${NOSNIFF:-<không có>}"

# NEGATIVE — chứng minh header KHÔNG đến từ kho lưu trữ.
# S3 không có cách nào trả về header này từ metadata của object; nếu bạn thấy
# nó ở phản hồi biên mà không thấy ở metadata thì nó do biên sinh ra.
META=$(aws s3api head-object --bucket "$KHO" --key tinh/thu.txt \
  --query 'to_string(Metadata)' --output text 2>/dev/null)
case "${META:-}" in
*ontent*ype*ptions* | *nosniff*)
  fail "header KHÔNG do kho lưu trữ đính kèm" \
    "metadata của object không chứa header bảo mật" \
    "metadata: $META — bạn đang gắn header vào từng file, cách này không mở rộng được"
  ;;
*)
  ok "header do tầng biên sinh ra, không do kho đính kèm" "metadata sạch"
  ;;
esac

# ---------------------------------------------------------------------------
section "6. Tên miền riêng (yêu cầu 5 — tuỳ chọn)"
# ---------------------------------------------------------------------------

if [ -z "$TEN_MIEN" ] || [ -z "$VUNG_DNS" ]; then
  printf '  %s·%s bỏ qua — không khai output ten_mien/vung_dns.\n' $'\033[2m' $'\033[0m'
  printf '      Đây KHÔNG phải lỗi: hosted zone tốn $0,50/tháng và lab không bắt bạn trả.\n'
  printf '      Bù lại, bạn phải tự trả lời được câu cuối trong "Tiêu chí đạt".\n'
else
  RRS=$(aws route53 list-resource-record-sets --hosted-zone-id "$VUNG_DNS" \
    --query "ResourceRecordSets[?Name=='${TEN_MIEN}.']" --output json 2>/dev/null)

  LOAI=$(printf '%s' "$RRS" | python3 -c '
import sys, json
try:
    rs = json.load(sys.stdin)
except Exception:
    rs = []
for r in rs:
    if r.get("AliasTarget"):
        print("ALIAS " + r.get("Type","") + " " + r["AliasTarget"].get("DNSName","").rstrip("."))
        break
else:
    print(" ".join(r.get("Type","") for r in rs) or "<không có bản ghi>")
' 2>/dev/null)

  case "$LOAI" in
  "ALIAS A "*)
    ok "tên miền trỏ vào biên bằng bản ghi Alias kiểu A" "$LOAI"
    DICH=${LOAI##* }
    assert_eq "Alias trỏ đúng vào điểm biên của lab" "$BIEN" "$DICH"
    ;;
  CNAME*)
    fail "tên miền trỏ vào biên bằng bản ghi Alias" \
      "Alias kiểu A (miễn phí truy vấn, dùng được ở gốc tên miền)" \
      "CNAME — CNAME không đặt được ở gốc tên miền và bị tính phí truy vấn"
    ;;
  *)
    fail "tên miền trỏ vào biên bằng bản ghi Alias" "Alias kiểu A" "$LOAI"
    ;;
  esac
fi

# ---------------------------------------------------------------------------
if summary; then
  cat <<'EOF'

Hai câu tự hỏi trước khi đọc DOI-CHIEU.md:

  1. Bạn vừa chứng minh /tinh/* bỏ query string ra khỏi cache key. Vậy nếu đội
     frontend cần một cách khác để ép trình duyệt lấy file mới sau mỗi lần
     build, họ làm thế nào mà KHÔNG làm vỡ tỉ lệ trúng cache ở biên?
     (Gợi ý: đổi cái gì trong URL thì biên buộc phải coi là tài nguyên khác?)

  2. /api/* của bạn đang không cache gì cả. Giả sử sếp nói "cache 5 giây thôi
     cũng được, để chịu được đợt spike". Thay đổi đó làm giảm tải origin bao
     nhiêu lần khi có 10.000 request/giây? Và nó tạo ra rủi ro gì mà 5 giây
     trước không có?
EOF
fi
