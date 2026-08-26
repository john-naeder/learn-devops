#!/usr/bin/env bash
# Trọng tài của lab tuần 7.
#
# Không đọc một dòng .tf nào. Lab này khác các lab khác ở một điểm: nó KHÔNG
# chỉ đọc. Không bơm message vào thì không có cách nào chứng minh message đi
# đâu — nên script này gửi vài đơn hàng thử, quan sát chúng chạy, rồi dọn sạch
# những gì nó đã gửi. Chạy lại bao nhiêu lần cũng cho cùng kết quả.
#
# Ba thứ được quan sát theo thời gian thật, mỗi thứ có hạn giờ rõ ràng:
#   - message đi từ điểm phát tán tới từng hàng đợi
#   - message quay lại hàng đợi sau khi hết visibility timeout
#   - message hỏng rơi xuống nơi cách ly sau đúng số lần thử đã cấu hình
set -uo pipefail
cd "$(dirname "$0")" || exit 1
source ../_lib/check.sh

export AWS_PROFILE="${LAB_PROFILE:-lab-builder}"
export AWS_REGION="us-east-1"
export AWS_DEFAULT_REGION="us-east-1"

check_init "Tuần 7 — Một lần phát, nhiều nơi nhận, và đơn độc thì đi đâu"

KENH=$(need_output kenh_don_hang)      || exit 1
Q_KT=$(need_output hang_doi_ketoan)    || exit 1
Q_GL=$(need_output hang_doi_gianlan)   || exit 1
Q_CL=$(need_output hang_doi_cach_ly)   || exit 1

# ---------------------------------------------------------------------------
# Công cụ
# ---------------------------------------------------------------------------

# attr <queue-url> <tên attribute> -> in giá trị, rỗng nếu không có
attr() {
  aws sqs get-queue-attributes --queue-url "$1" --attribute-names "$2" \
    --query "Attributes.$2" --output text 2>/dev/null | sed 's/^None$//'
}

# Tách JSON của ReceiveMessage: dòng 1 là FOUND/NOTFOUND, các dòng sau là
# ReceiptHandle. Dùng python3 vì thân message là JSON lồng nhau, cắt bằng
# sed/awk sẽ vỡ ngay khi SNS bọc phong bì quanh nó.
_doc() {
  python3 -c '
import sys, json
ma = sys.argv[1]
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
msgs = d.get("Messages") or []
print("FOUND" if any(ma in (m.get("Body") or "") for m in msgs) else "NOTFOUND")
for m in msgs:
    print(m.get("ReceiptHandle",""))
' "$1"
}

# hut <queue-url> <ma_don|-> <giây chờ mỗi nhịp> -> in FOUND/NOTFOUND, xoá sạch
# mọi message nhận được trong nhịp đó.
hut() {
  local q="$1" ma="${2:--khong-tim-gi-}" cho="$3" kq h
  kq=$(aws sqs receive-message --queue-url "$q" --max-number-of-messages 10 \
    --visibility-timeout 0 --wait-time-seconds "$cho" --output json 2>/dev/null | _doc "$ma")
  [ -z "$kq" ] && { echo NOTFOUND; return 0; }
  printf '%s\n' "$kq" | tail -n +2 | while IFS= read -r h; do
    [ -n "$h" ] && aws sqs delete-message --queue-url "$q" --receipt-handle "$h" >/dev/null 2>&1
  done
  printf '%s\n' "$kq" | head -1
}

# don_sach <queue-url...> — vét sạch hàng đợi trước mỗi thí nghiệm
don_sach() {
  local q i
  for q in "$@"; do
    for i in 1 2 3 4 5 6 7 8; do
      [ "$(hut "$q" - 1)" = "NOTFOUND" ] && break
    done
  done
}

# cho_thay <queue-url> <ma_don> <hạn giây> -> 0 nếu thấy trong hạn
# In tiến độ. KHÔNG BAO GIỜ chờ vô hạn.
cho_thay() {
  local q="$1" ma="$2" han="$3" troi=0
  printf '    chờ %s tới nơi ' "$ma"
  while [ "$troi" -lt "$han" ]; do
    if [ "$(hut "$q" "$ma" 5)" = "FOUND" ]; then printf ' [%ds]\n' "$troi"; return 0; fi
    troi=$((troi + 5)); printf '.'
  done
  printf ' [hết %ds]\n' "$han"
  return 1
}

# khong_thay <queue-url> <ma_don> <giây quan sát> -> 0 nếu SUỐT thời gian đó
# không thấy. Đây là công cụ của các negative check.
khong_thay() {
  local q="$1" ma="$2" han="$3" troi=0
  printf '    canh %s trong %ds ' "$ma" "$han"
  while [ "$troi" -lt "$han" ]; do
    if [ "$(hut "$q" "$ma" 5)" = "FOUND" ]; then printf ' THẤY [%ds]\n' "$troi"; return 1; fi
    troi=$((troi + 5)); printf '.'
  done
  printf ' sạch\n'
  return 0
}

# gui_don <ma_don> <gia_tri> — gửi vào điểm phát tán, tự nhận ra SNS hay EventBridge
gui_don() {
  local ma="$1" gt="$2"
  case "$KENH" in
  *:sns:*)
    aws sns publish --topic-arn "$KENH" \
      --message "{\"ma_don\":\"$ma\",\"gia_tri\":$gt}" \
      --message-attributes "gia_tri={DataType=Number,StringValue=$gt}" >/dev/null 2>&1
    ;;
  *:events:*)
    aws events put-events --entries "$(printf \
      '[{"Source":"self.w07","DetailType":"don-hang","EventBusName":"%s","Detail":"{\\"ma_don\\":\\"%s\\",\\"gia_tri\\":%s}"}]' \
      "$KENH" "$ma" "$gt")" >/dev/null 2>&1
    ;;
  *) return 2 ;;
  esac
}

MA_THUONG="thuong-$$-$RANDOM"
MA_LON="lon-$$-$RANDOM"
MA_VIS="vis-$$-$RANDOM"
MA_HONG="hong-$$-$RANDOM"

echo
echo "  (verify.sh gửi 4 đơn hàng thử rồi dọn sạch — mất khoảng 7 phút)"

# ---------------------------------------------------------------------------
section "1. Điểm phát tán"
# ---------------------------------------------------------------------------

case "$KENH" in
*:sns:*) ok "kênh phát tán là một topic pub/sub" "$KENH" ;;
*:events:*) ok "kênh phát tán là một event bus" "$KENH" ;;
*) fail "kênh phát tán phải là ARN của SNS topic hoặc EventBridge bus" \
  "ARN chứa :sns: hoặc :events:" "$KENH" ;;
esac

don_sach "$Q_KT" "$Q_GL" "$Q_CL"

# ---------------------------------------------------------------------------
section "2. Một lần phát, nhiều nơi nhận (yêu cầu 1 và 2)"
# ---------------------------------------------------------------------------

if gui_don "$MA_THUONG" 10; then
  if cho_thay "$Q_KT" "$MA_THUONG" 90; then
    ok "đơn thường (gia_tri=10) tới được kế toán" "$MA_THUONG"
  else
    fail "đơn thường tới được kế toán" "thấy trong 90 giây" "không thấy — kiểm tra subscription và policy của hàng đợi"
  fi

  # NEGATIVE — lọc phải xảy ra TRƯỚC khi tới nơi, không phải consumer tự bỏ qua
  if khong_thay "$Q_GL" "$MA_THUONG" 45; then
    ok "đơn thường KHÔNG lọt sang chống gian lận" "sạch suốt 45 giây"
  else
    fail "đơn thường KHÔNG lọt sang chống gian lận" \
      "không bao giờ xuất hiện" "đã xuất hiện — bộ lọc chưa chặn ở nguồn"
  fi
else
  fail "gửi được đơn vào điểm phát tán" "publish thành công" "lệnh gửi thất bại — kiểm tra quyền và ARN"
fi

if gui_don "$MA_LON" 5000; then
  if cho_thay "$Q_KT" "$MA_LON" 90; then
    ok "đơn lớn (gia_tri=5000) tới được kế toán" "$MA_LON"
  else
    fail "đơn lớn tới được kế toán" "thấy trong 90 giây" "không thấy"
  fi
  if cho_thay "$Q_GL" "$MA_LON" 90; then
    ok "đơn lớn tới được chống gian lận" "$MA_LON"
  else
    fail "đơn lớn tới được chống gian lận" "thấy trong 90 giây" \
      "không thấy — bộ lọc đang chặn cả đơn đáng lẽ phải qua"
  fi
else
  fail "gửi được đơn lớn" "publish thành công" "lệnh gửi thất bại"
fi

# ---------------------------------------------------------------------------
section "3. Đang xử lý thì không ai giành mất (yêu cầu 3)"
# ---------------------------------------------------------------------------

VIS=$(attr "$Q_KT" VisibilityTimeout)
if [ -n "$VIS" ] && [ "$VIS" -ge 20 ] 2>/dev/null && [ "$VIS" -le 60 ] 2>/dev/null; then
  ok "visibility timeout nằm trong 20–60 giây" "${VIS}s"
else
  fail "visibility timeout nằm trong 20–60 giây" "20 <= x <= 60" "${VIS:-<không đọc được>}"
fi

don_sach "$Q_KT"
gui_don "$MA_VIS" 20
sleep 5

# Nhận nhưng KHÔNG xoá — mô phỏng worker đang xử lý
GIU=$(aws sqs receive-message --queue-url "$Q_KT" --max-number-of-messages 1 \
  --wait-time-seconds 20 --output json 2>/dev/null | _doc "$MA_VIS")
if [ "$(printf '%s\n' "$GIU" | head -1)" = "FOUND" ]; then
  ok "worker thứ nhất nhận được đơn" "$MA_VIS"

  # NEGATIVE — worker thứ hai không được giành mất
  NGAY=$(aws sqs receive-message --queue-url "$Q_KT" --max-number-of-messages 1 \
    --visibility-timeout 0 --wait-time-seconds 10 --output json 2>/dev/null | _doc "$MA_VIS")
  if [ "$(printf '%s\n' "$NGAY" | head -1)" = "NOTFOUND" ]; then
    ok "worker thứ hai KHÔNG giành được đơn đang xử lý" "hàng đợi im lặng sau 10 giây"
  else
    fail "worker thứ hai KHÔNG giành được đơn đang xử lý" \
      "không nhận được gì" "nhận được cùng một đơn — visibility timeout đang là 0 hoặc quá ngắn"
  fi

  # Worker "chết": không xoá, không gia hạn. Đơn phải tự quay lại.
  printf '    chờ đơn tự quay lại hàng đợi '
  TROI=0
  QUAY=0
  while [ "$TROI" -lt 90 ]; do
    if [ "$(hut "$Q_KT" "$MA_VIS" 5)" = "FOUND" ]; then QUAY=1; break; fi
    TROI=$((TROI + 5))
    printf '.'
  done
  printf ' [%ds]\n' "$TROI"

  if [ "$QUAY" -eq 1 ] && [ "$TROI" -le 75 ]; then
    ok "worker chết thì đơn tự quay lại trong 60 giây" "quay lại sau ~${TROI}s"
  else
    fail "worker chết thì đơn tự quay lại trong 60 giây" \
      "quay lại trước giây thứ 75" "sau 90 giây vẫn chưa quay lại"
  fi
else
  fail "worker thứ nhất nhận được đơn" "nhận được $MA_VIS" "hàng đợi rỗng — đơn chưa tới hoặc đã bị ai đó lấy"
fi

# ---------------------------------------------------------------------------
section "4. Đơn độc bị cách ly, không bị mất (yêu cầu 4 và 5)"
# ---------------------------------------------------------------------------

RP=$(attr "$Q_KT" RedrivePolicy)
if [ -n "$RP" ]; then
  MAXRC=$(printf '%s' "$RP" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("maxReceiveCount",""))' 2>/dev/null)
  DLQ_ARN_CAUHINH=$(printf '%s' "$RP" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("deadLetterTargetArn",""))' 2>/dev/null)
else
  MAXRC=""
  DLQ_ARN_CAUHINH=""
fi
DLQ_ARN_THAT=$(attr "$Q_CL" QueueArn)

assert_eq "sau đúng 3 lần giao thì đơn bị cách ly" "3" "${MAXRC:-<chưa cấu hình chuyển tiếp>}"
assert_eq "nơi cách ly đúng là hàng đợi khai trong output" "$DLQ_ARN_THAT" "${DLQ_ARN_CAUHINH:-<rỗng>}"

# NEGATIVE — nơi cách ly không được cách ly tiếp (chống vòng lặp vô tận)
RP_CL=$(attr "$Q_CL" RedrivePolicy)
assert_eq "nơi cách ly KHÔNG có cơ chế chuyển tiếp của riêng nó" "" "${RP_CL:-}"

don_sach "$Q_KT" "$Q_CL"
gui_don "$MA_HONG" 20

if cho_thay "$Q_KT" "$MA_HONG" 90; then
  # Vừa hút một lần ở trên = lần giao thứ 1. Tiếp tục "làm hỏng" cho tới khi
  # đơn không còn xuất hiện ở hàng đợi chính nữa.
  DEM=1
  printf '    consumer chết đi chết lại '
  for _ in 1 2 3 4 5 6 7; do
    KQ=$(aws sqs receive-message --queue-url "$Q_KT" --max-number-of-messages 1 \
      --visibility-timeout 0 --wait-time-seconds 3 --output json 2>/dev/null | _doc "$MA_HONG")
    if [ "$(printf '%s\n' "$KQ" | head -1)" = "FOUND" ]; then
      DEM=$((DEM + 1))
      printf 'x'
    else
      printf '.'
    fi
  done
  printf ' [%d lần giao]\n' "$DEM"

  # SQS Standard là at-least-once: rất hiếm nhưng có thể giao thừa một lần.
  if [ "$DEM" -ge 3 ] && [ "$DEM" -le 4 ]; then
    ok "đơn hỏng được giao 3 lần rồi thôi" "$DEM lần"
  else
    fail "đơn hỏng được giao 3 lần rồi thôi" \
      "3 lần (SQS Standard có thể thành 4 vì at-least-once)" "$DEM lần"
  fi

  if cho_thay "$Q_CL" "$MA_HONG" 90; then
    ok "đơn hỏng nằm ở nơi cách ly, đội vận hành đọc được" "$MA_HONG"
  else
    fail "đơn hỏng nằm ở nơi cách ly" "thấy trong 90 giây" \
      "không thấy — hoặc chưa có redrive policy, hoặc trỏ sai hàng đợi"
  fi

  # NEGATIVE — bị cách ly rồi thì không được quay lại dây chuyền chính
  if khong_thay "$Q_KT" "$MA_HONG" 30; then
    ok "đơn đã cách ly KHÔNG quay lại hàng đợi chính" "sạch suốt 30 giây"
  else
    fail "đơn đã cách ly KHÔNG quay lại hàng đợi chính" \
      "không bao giờ xuất hiện lại" "đã xuất hiện lại"
  fi
else
  fail "đơn hỏng tới được hàng đợi chính để bắt đầu thí nghiệm" "thấy trong 90 giây" "không thấy"
fi

# ---------------------------------------------------------------------------
section "5. Hỏi hàng đợi rỗng không được trả lời ngay (yêu cầu 6)"
# ---------------------------------------------------------------------------

WAIT=$(attr "$Q_KT" ReceiveMessageWaitTimeSeconds)
if [ -n "$WAIT" ] && [ "$WAIT" -ge 10 ] 2>/dev/null; then
  ok "hàng đợi mặc định chờ ít nhất 10 giây" "${WAIT}s"
else
  fail "hàng đợi mặc định chờ ít nhất 10 giây" ">= 10" "${WAIT:-0} — đang là short polling, tốn tiền request"
fi

don_sach "$Q_KT"
T0=$(date +%s)
aws sqs receive-message --queue-url "$Q_KT" --max-number-of-messages 1 --output json >/dev/null 2>&1
T1=$(date +%s)
DELTA=$((T1 - T0))
if [ "$DELTA" -ge 8 ]; then
  ok "hỏi thật một hàng đợi rỗng: bị giữ lại chờ" "${DELTA}s"
else
  fail "hỏi thật một hàng đợi rỗng: bị giữ lại chờ" \
    ">= 8 giây (long polling có hiệu lực)" "${DELTA}s — trả lời tức thì"
fi

don_sach "$Q_KT" "$Q_GL" "$Q_CL"

# ---------------------------------------------------------------------------
if summary; then
  cat <<'EOF'

Hai câu tự hỏi trước khi đọc DOI-CHIEU.md:

  1. Bạn vừa chứng kiến một đơn quay lại hàng đợi sau khi worker "chết".
     Nếu worker KHÔNG chết mà chỉ chạy chậm hơn visibility timeout, chuyện gì
     xảy ra? Hệ thống của bạn có ghi sổ kế toán hai lần không? Nếu có, thì
     sửa ở đâu — SQS, hay chỗ ghi sổ?

  2. maxReceiveCount = 3 nghĩa là đơn hỏng chiếm chỗ 3 lần rồi mới ra khỏi dây
     chuyền. Với 1 triệu đơn/ngày và 0,1% đơn hỏng, mỗi ngày có bao nhiêu lượt
     xử lý bị phí? Đặt maxReceiveCount = 1 có phải câu trả lời không, và tại sao
     gần như luôn không?
EOF
fi
