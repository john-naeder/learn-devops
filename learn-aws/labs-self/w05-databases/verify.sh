#!/usr/bin/env bash
# Trọng tài của lab tuần 5.
#
# Không đọc một dòng .tf nào, và cố ý KHÔNG BIẾT bạn đặt tên thuộc tính là gì.
# Nó hỏi thẳng AWS xem bảng có khoá nào, tên gì, kiểu gì, rồi TỰ DỰNG câu truy
# vấn từ đó. Bạn đặt tên `ma_khach`, `pk` hay `customer_id` đều được — cái nó
# không tha thứ là hình dạng khoá sai.
#
# Trái tim của lab nằm ở một phép so sánh duy nhất, lặp lại ba lần:
#
#     Count  ==  ScannedCount ?
#     (trả về)     (đọc)
#
# Bằng nhau nghĩa là kho dữ liệu nhảy thẳng tới chỗ cần. Lệch nghĩa là nó đang
# đi từ đầu bảng tới cuối và bạn đang trả tiền cho từng bản ghi không dùng tới.
#
# Chạy lại bao nhiêu lần cũng được. Script này CHỈ ĐỌC: query, scan, describe.
# Không ghi, không sửa, không xoá một bản ghi nào.
set -uo pipefail
cd "$(dirname "$0")" || exit 1
source ../_lib/check.sh

export AWS_PROFILE="${LAB_PROFILE:-lab-builder}"
export AWS_REGION="us-east-1"
export AWS_DEFAULT_REGION="us-east-1"

check_init "Tuần 5 — Đọc đúng thứ mình cần: thiết kế khoá, Query, chỉ mục phụ, TTL"

BANG=$(need_output table_name)                || exit 1
GSI=$(need_output gsi_name)                   || exit 1
KHACH=$(need_output khach_mau)                || exit 1
SO_DON=$(need_output so_don_cua_khach_mau)    || exit 1
TRANG_THAI=$(need_output trang_thai_mau)      || exit 1
SO_TT=$(need_output so_don_trang_thai_mau)    || exit 1
CHI_PHI=$(need_output chi_phi)                || exit 1

# --- tiện ích ---------------------------------------------------------------

ddb() { aws dynamodb "$@" 2>/dev/null; }

mota_bang() {  # mota_bang <jmespath> -> giá trị text
  ddb describe-table --table-name "$BANG" --query "$1" --output text
}

av() {  # av <S|N> <giá trị> -> {"S":"..."}
  printf '{"%s":"%s"}' "$1" "$2"
}

# so_sanh_doc_va_tra <mô tả> <Count> <ScannedCount>
so_sanh_doc_va_tra() {
  local mota="$1" c="$2" s="$3"
  if [ "$c" = "$s" ]; then
    ok "$mota" "đọc $s / trả về $c — không thừa bản ghi nào"
  else
    fail "$mota" "ScannedCount == Count (== $c)" \
      "đọc $s để trả về $c — thừa $((s - c)) bản ghi, và bạn trả tiền cho cả $s"
  fi
}

tong() { awk '{t+=$1} END {printf "%d", t+0}'; }

# ---------------------------------------------------------------------------
section "Bảng tồn tại và có hình dạng khoá dùng được"

TRANG_THAI_BANG=$(mota_bang 'Table.TableStatus')
if [ "$TRANG_THAI_BANG" != "ACTIVE" ]; then
  fail "bảng ở trạng thái ACTIVE" "ACTIVE" "${TRANG_THAI_BANG:-không đọc được bảng \"$BANG\"}"
  summary
  exit 1
fi
ok "bảng tồn tại và đang phục vụ" "$BANG"

PK=$(mota_bang "Table.KeySchema[?KeyType=='HASH'] | [0].AttributeName")
SK=$(mota_bang "Table.KeySchema[?KeyType=='RANGE'] | [0].AttributeName")
PK_TYPE=$(mota_bang "Table.AttributeDefinitions[?AttributeName=='${PK}'] | [0].AttributeType")

if [ -n "$PK" ] && [ "$PK" != "None" ]; then
  ok "bảng có khoá phân hoạch" "$PK ($PK_TYPE)"
else
  fail "bảng có khoá phân hoạch" "một thuộc tính KeyType=HASH" "không có"
  summary
  exit 1
fi

if [ -n "$SK" ] && [ "$SK" != "None" ]; then
  SK_TYPE=$(mota_bang "Table.AttributeDefinitions[?AttributeName=='${SK}'] | [0].AttributeType")
  ok "bảng có khoá sắp xếp" "$SK ($SK_TYPE)"
else
  fail "bảng có khoá sắp xếp" \
    "một thuộc tính KeyType=RANGE — thiếu nó thì không có thứ tự và không lọc theo khoảng được" \
    "không có"
  summary
  exit 1
fi

GSI_TT=$(mota_bang "Table.GlobalSecondaryIndexes[?IndexName=='${GSI}'] | [0].IndexStatus")
GPK=$(mota_bang "Table.GlobalSecondaryIndexes[?IndexName=='${GSI}'].KeySchema[?KeyType=='HASH'].AttributeName | [] | [0]")
GPK_TYPE=$(mota_bang "Table.AttributeDefinitions[?AttributeName=='${GPK}'] | [0].AttributeType")
CHIEU=$(mota_bang "Table.GlobalSecondaryIndexes[?IndexName=='${GSI}'] | [0].Projection.ProjectionType")

if [ "$GSI_TT" = "ACTIVE" ]; then
  ok "chỉ mục phụ đã sẵn sàng" "$GSI — khoá phân hoạch $GPK, chiếu $CHIEU"
else
  fail "chỉ mục phụ đã sẵn sàng" "IndexStatus=ACTIVE" \
    "${GSI_TT:-không có chỉ mục tên \"$GSI\"} (chỉ mục mới tạo cần vài chục giây tới vài phút)"
fi

if [ "$GPK" != "$PK" ] && [ -n "$GPK" ] && [ "$GPK" != "None" ]; then
  ok "chỉ mục phụ đổi được khoá phân hoạch" "$PK -> $GPK"
else
  fail "chỉ mục phụ đổi được khoá phân hoạch" \
    "khoá phân hoạch của chỉ mục KHÁC khoá phân hoạch của bảng" \
    "${GPK:-không đọc được} — nếu nó trùng \"$PK\" thì bạn đang dùng loại chỉ mục sai cho câu hỏi 2"
fi

# ---------------------------------------------------------------------------
section "Dữ liệu đủ để chấm (yêu cầu 1, 9)"

read -r TONG_ITEM TONG_QUET < <(
  ddb scan --table-name "$BANG" --no-paginate --select COUNT \
    --query '[Count,ScannedCount]' --output text
)

if [ "${TONG_ITEM:-0}" -ge 80 ] 2>/dev/null; then
  ok "bảng có đủ dữ liệu để phép so sánh có ý nghĩa" "$TONG_ITEM bản ghi"
else
  fail "bảng có ít nhất 80 bản ghi" ">= 80" \
    "${TONG_ITEM:-0} — với ít dữ liệu hơn thì Query và Scan trông giống nhau và lab không dạy được gì"
fi

SO_KHACH=$(
  ddb scan --table-name "$BANG" --no-paginate \
    --projection-expression "#h" --expression-attribute-names "{\"#h\":\"$PK\"}" \
    --query "Items[].\"${PK}\".${PK_TYPE}" --output text |
    tr -s '[:space:]' '\n' | grep -v '^$' | sort -u | grep -c '.'
)
if [ "${SO_KHACH:-0}" -ge 10 ] 2>/dev/null; then
  ok "khoá phân hoạch tản đều, không dồn vào một chỗ" "$SO_KHACH giá trị khác nhau"
else
  fail "khoá phân hoạch có ít nhất 10 giá trị khác nhau" ">= 10" \
    "${SO_KHACH:-0} — ít giá trị nghĩa là dữ liệu dồn vào ít phân hoạch. Tra từ khoá hot partition"
fi

# ---------------------------------------------------------------------------
section "Câu hỏi 1 — đơn của một khách (yêu cầu 2, 5)"

PKV=$(av "$PK_TYPE" "$KHACH")

read -r C1 S1 RCU1 < <(
  ddb query --table-name "$BANG" --no-paginate \
    --key-condition-expression "#h = :v" \
    --expression-attribute-names "{\"#h\":\"$PK\"}" \
    --expression-attribute-values "{\":v\":$PKV}" \
    --return-consumed-capacity TOTAL \
    --query '[Count,ScannedCount,ConsumedCapacity.CapacityUnits]' --output text
)

if [ -z "${C1:-}" ]; then
  fail "hỏi được các đơn của khách \"$KHACH\"" "một kết quả Query" \
    "Query thất bại — kiểm tra khach_mau có đúng là một giá trị của thuộc tính \"$PK\" không"
  summary
  exit 1
fi

assert_eq "số đơn trả về khớp hợp đồng output" "$SO_DON" "$C1"
so_sanh_doc_va_tra "PHỦ ĐỊNH: câu hỏi 1 không đọc thừa bản ghi nào" "$C1" "$S1"

if [ "${C1:-0}" -ge 8 ] 2>/dev/null; then
  ok "khách mẫu có đủ đơn để kiểm tra thứ tự và khoảng" "$C1 đơn, tốn $RCU1 RCU"
else
  fail "khách mẫu có ít nhất 8 đơn" ">= 8" "${C1:-0}"
fi

# --- thứ tự -----------------------------------------------------------------
truy_van_lay_khoa() {  # truy_van_lay_khoa [--no-scan-index-forward]
  ddb query --table-name "$BANG" --no-paginate "$@" \
    --key-condition-expression "#h = :v" \
    --expression-attribute-names "{\"#h\":\"$PK\"}" \
    --expression-attribute-values "{\":v\":$PKV}" \
    --query "Items[].\"${SK}\".${SK_TYPE}" --output text |
    tr -s '[:space:]' '\n' | grep -v '^$'
}

mapfile -t TANG < <(truy_van_lay_khoa)
mapfile -t GIAM < <(truy_van_lay_khoa --no-scan-index-forward)

N=${#TANG[@]}
DAO=""
for ((i = N - 1; i >= 0; i--)); do DAO="${DAO}${TANG[i]}"$'\n'; done
GIAM_CHUOI=""
for v in "${GIAM[@]}"; do GIAM_CHUOI="${GIAM_CHUOI}${v}"$'\n'; done

if [ "$N" -gt 0 ] && [ "$DAO" = "$GIAM_CHUOI" ]; then
  ok "lấy được kết quả theo thứ tự đảo ngược (mới nhất trước)" \
    "${GIAM[0]} ... ${GIAM[N - 1]}"
else
  fail "lấy được kết quả theo thứ tự đảo ngược (mới nhất trước)" \
    "danh sách giảm dần theo \"$SK\" là nghịch đảo đúng của danh sách tăng dần" \
    "hai danh sách không khớp — kiểm tra lại khoá sắp xếp"
fi

SO_TRUNG=$(printf '%s\n' "${TANG[@]}" | sort -u | grep -c '.')
assert_eq "mỗi đơn của khách có một giá trị khoá sắp xếp riêng" "$N" "${SO_TRUNG:-0}"

# --- lọc theo khoảng --------------------------------------------------------
section "Câu hỏi 1 có lọc thời gian (yêu cầu 3, 5)"

if [ "$N" -lt 2 ]; then
  fail "có đủ đơn để kiểm tra lọc theo khoảng" ">= 2 đơn cho khách mẫu" "$N"
  summary
  exit 1
fi

M=$((N / 2))
MOC="${TANG[M]}"
MONG=$((N - M))
MOCV=$(av "$SK_TYPE" "$MOC")

read -r C2 S2 RCU2 < <(
  ddb query --table-name "$BANG" --no-paginate \
    --key-condition-expression "#h = :v AND #r >= :m" \
    --expression-attribute-names "{\"#h\":\"$PK\",\"#r\":\"$SK\"}" \
    --expression-attribute-values "{\":v\":$PKV,\":m\":$MOCV}" \
    --return-consumed-capacity TOTAL \
    --query '[Count,ScannedCount,ConsumedCapacity.CapacityUnits]' --output text
)

assert_eq "hỏi \"từ mốc $MOC trở đi\" trả đúng số đơn" "$MONG" "${C2:-0}"
so_sanh_doc_va_tra "PHỦ ĐỊNH: lọc theo khoảng cũng không đọc thừa" "${C2:-0}" "${S2:-0}"
echo "      (thu hẹp từ $N xuống $MONG bản ghi mà chỉ tốn $RCU2 RCU — vì khoá sắp xếp"
echo "       giữ dữ liệu ĐÃ SẮP SẴN, không phải vì có ai đi lọc hộ bạn)"

# ---------------------------------------------------------------------------
section "Câu hỏi 2 — mọi đơn ở một trạng thái (yêu cầu 4, 5)"

if [ -n "$GPK" ] && [ "$GPK" != "None" ]; then
  GV=$(av "${GPK_TYPE:-S}" "$TRANG_THAI")
  read -r C3 S3 RCU3 < <(
    ddb query --table-name "$BANG" --index-name "$GSI" --no-paginate \
      --key-condition-expression "#h = :v" \
      --expression-attribute-names "{\"#h\":\"$GPK\"}" \
      --expression-attribute-values "{\":v\":$GV}" \
      --return-consumed-capacity TOTAL \
      --query '[Count,ScannedCount,ConsumedCapacity.CapacityUnits]' --output text
  )
  if [ -n "${C3:-}" ]; then
    assert_eq "số đơn ở trạng thái \"$TRANG_THAI\" khớp hợp đồng output" "$SO_TT" "$C3"
    so_sanh_doc_va_tra "PHỦ ĐỊNH: câu hỏi 2 không đọc thừa bản ghi nào" "$C3" "$S3"
    echo "      (chỉ mục phụ tốn $RCU3 RCU — capacity của nó tách riêng khỏi bảng gốc)"
  else
    fail "hỏi được mọi đơn ở trạng thái \"$TRANG_THAI\"" "một kết quả Query trên chỉ mục" \
      "Query trên chỉ mục thất bại — kiểm tra trang_thai_mau có đúng là giá trị của \"$GPK\" không"
  fi
else
  fail "hỏi được mọi đơn ở trạng thái \"$TRANG_THAI\"" \
    "một chỉ mục phụ có khoá phân hoạch riêng" "không có chỉ mục dùng được"
fi

# ---------------------------------------------------------------------------
section "PHỦ ĐỊNH — hai cách làm SAI phải hỏng, hoặc phải đắt (yêu cầu 6, 7)"

# (1) Hỏi mà thiếu khoá phân hoạch: kho dữ liệu phải TỪ CHỐI, không phải
#     "chạy chậm". Đây là khác biệt cốt lõi với một database quan hệ.
assert_cmd_fail "hỏi bằng riêng mốc thời gian, không có khoá phân hoạch, bị TỪ CHỐI" \
  aws dynamodb query --table-name "$BANG" \
  --key-condition-expression "#r >= :m" \
  --expression-attribute-names "{\"#r\":\"$SK\"}" \
  --expression-attribute-values "{\":m\":$MOCV}"

# (2) Cách "đọc cả bảng rồi lọc": ĐÚNG kết quả, nhưng phải đọc cả bảng.
#     FilterExpression chạy SAU khi dữ liệu đã được đọc và đã tính tiền —
#     nó làm Count nhỏ đi mà không làm ScannedCount nhỏ đi.
read -r C4 S4 RCU4 < <(
  ddb scan --table-name "$BANG" --no-paginate \
    --filter-expression "#h = :v" \
    --expression-attribute-names "{\"#h\":\"$PK\"}" \
    --expression-attribute-values "{\":v\":$PKV}" \
    --return-consumed-capacity TOTAL \
    --query '[Count,ScannedCount,ConsumedCapacity.CapacityUnits]' --output text
)

assert_eq "cách sai cho ra ĐÚNG CÙNG một câu trả lời" "$C1" "${C4:-0}"

if [ "${S4:-0}" -gt "${S1:-0}" ] 2>/dev/null; then
  TI_LE=$((S4 * 100 / (C4 > 0 ? C4 : 1)))
  ok "PHỦ ĐỊNH: nhưng nó đọc nhiều hơn hẳn để lấy về đúng chừng đó" \
    "Scan đọc $S4 / trả về $C4  (${TI_LE}% — Query chỉ đọc $S1)"
  echo
  echo "      Query : đọc $S1 bản ghi, tốn $RCU1 RCU"
  echo "      Scan  : đọc $S4 bản ghi, tốn $RCU4 RCU   <-- gấp $((S4 / (S1 > 0 ? S1 : 1))) lần, cùng kết quả"
  echo
  echo "      Nhân con số này với một bảng 5 triệu dòng và một màn hình làm mới"
  echo "      30 giây một lần. Đó là hoá đơn gấp bốn mươi lần trong đề bài."
  echo
else
  fail "PHỦ ĐỊNH: cách 'đọc cả bảng rồi lọc' phải đọc nhiều hơn Query" \
    "ScannedCount của Scan > ScannedCount của Query ($S1)" \
    "Scan đọc ${S4:-?} — bảng đang quá nhỏ để phép so sánh có ý nghĩa"
fi

# ---------------------------------------------------------------------------
section "Bản ghi tạm tự biến mất (yêu cầu 8)"

TTL_TT=$(ddb describe-time-to-live --table-name "$BANG" \
  --query 'TimeToLiveDescription.TimeToLiveStatus' --output text)
TTL_ATTR=$(ddb describe-time-to-live --table-name "$BANG" \
  --query 'TimeToLiveDescription.AttributeName' --output text)

assert_eq "cơ chế tự hết hạn đang bật" "ENABLED" "${TTL_TT:-DISABLED}"

if [ -n "$TTL_ATTR" ] && [ "$TTL_ATTR" != "None" ]; then
  SO_CO_TTL=$(ddb scan --table-name "$BANG" --no-paginate --select COUNT \
    --filter-expression "attribute_exists(#t)" \
    --expression-attribute-names "{\"#t\":\"$TTL_ATTR\"}" \
    --query 'Count' --output text)

  if [ "${SO_CO_TTL:-0}" -ge 1 ] 2>/dev/null; then
    ok "có bản ghi thật mang thuộc tính hết hạn" "$SO_CO_TTL bản ghi mang \"$TTL_ATTR\""
  else
    fail "có bản ghi thật mang thuộc tính hết hạn" \
      ">= 1 bản ghi có thuộc tính \"$TTL_ATTR\"" \
      "0 — TTL bật trên một thuộc tính không tồn tại thì không bao giờ xoá gì cả, và AWS không báo lỗi"
  fi

  MAU=$(ddb scan --table-name "$BANG" --max-items 1 \
    --filter-expression "attribute_exists(#t)" \
    --expression-attribute-names "{\"#t\":\"$TTL_ATTR\"}" \
    --query "Items[0].\"${TTL_ATTR}\"" --output json | tr -d ' \n')

  case "$MAU" in
  '{"N":'*)
    ok "PHỦ ĐỊNH: giá trị hết hạn đúng kiểu Number" "$MAU"
    GIA=$(printf '%s' "$MAU" | sed 's/[^0-9]//g')
    NOW=$(date +%s)
    if [ -n "$GIA" ] && [ "$GIA" -gt "$NOW" ] 2>/dev/null && [ "$GIA" -lt $((NOW + 315360000)) ] 2>/dev/null; then
      ok "mốc hết hạn ở tương lai gần, đơn vị giây" \
        "$GIA (còn $(((GIA - NOW) / 3600)) giờ)"
    elif [ -n "$GIA" ] && [ "$GIA" -ge $((NOW + 315360000)) ] 2>/dev/null; then
      fail "mốc hết hạn ở tương lai gần, đơn vị GIÂY" \
        "epoch tính bằng giây (10 chữ số)" \
        "$GIA — con số này là mili-giây. Bản ghi sẽ hết hạn vào khoảng năm $((1970 + GIA / 31536000000))"
    else
      fail "mốc hết hạn ở tương lai" "một epoch lớn hơn $NOW" \
        "${GIA:-không đọc được} — mốc trong quá khứ nghĩa là bản ghi đáng lẽ đã bị xoá"
    fi
    ;;
  '{"S":'*)
    fail "PHỦ ĐỊNH: giá trị hết hạn đúng kiểu Number" \
      "kiểu N (Number)" \
      "$MAU — đây là kiểu String. TTL BỎ QUA nó, vĩnh viễn, không một dòng log nào. Đây là chỗ hỏng im lặng kinh điển nhất của DynamoDB"
    ;;
  *)
    fail "PHỦ ĐỊNH: giá trị hết hạn đúng kiểu Number" \
      "một giá trị kiểu N" "${MAU:-không lấy được bản ghi mẫu nào}"
    ;;
  esac
else
  fail "TTL khai báo một thuộc tính cụ thể" "tên thuộc tính" "không có"
fi

# ---------------------------------------------------------------------------
section "Khôi phục và chi phí (yêu cầu 10, 11)"

PITR=$(ddb describe-continuous-backups --table-name "$BANG" \
  --query 'ContinuousBackupsDescription.PointInTimeRecoveryDescription.PointInTimeRecoveryStatus' \
  --output text)
if [ "$PITR" = "ENABLED" ]; then
  MOC_SOM=$(ddb describe-continuous-backups --table-name "$BANG" \
    --query 'ContinuousBackupsDescription.PointInTimeRecoveryDescription.EarliestRestorableDateTime' \
    --output text)
  ok "khôi phục được về bất kỳ thời điểm nào trong 35 ngày qua" "sớm nhất: $MOC_SOM"
else
  fail "khôi phục được về bất kỳ thời điểm nào trong 35 ngày qua" \
    "PointInTimeRecoveryStatus=ENABLED" \
    "${PITR:-DISABLED} — snapshot thủ công KHÔNG đạt yêu cầu này: nó chỉ khôi phục về đúng lúc bạn chụp"
fi

BM=$(mota_bang 'Table.BillingModeSummary.BillingMode')
if [ "$BM" = "PAY_PER_REQUEST" ]; then
  ok "chế độ tính tiền không phát sinh phí khi không ai gọi" "PAY_PER_REQUEST"
else
  R_BANG=$(mota_bang 'Table.ProvisionedThroughput.ReadCapacityUnits')
  W_BANG=$(mota_bang 'Table.ProvisionedThroughput.WriteCapacityUnits')
  R_GSI=$(mota_bang 'Table.GlobalSecondaryIndexes[].ProvisionedThroughput.ReadCapacityUnits' |
    tr -s '[:space:]' '\n' | grep -v '^$' | tong)
  W_GSI=$(mota_bang 'Table.GlobalSecondaryIndexes[].ProvisionedThroughput.WriteCapacityUnits' |
    tr -s '[:space:]' '\n' | grep -v '^$' | tong)
  TONG_R=$((${R_BANG:-0} + ${R_GSI:-0}))
  TONG_W=$((${W_BANG:-0} + ${W_GSI:-0}))
  if [ "$TONG_R" -le 25 ] && [ "$TONG_W" -le 25 ]; then
    ok "capacity provisioned nằm trong hạn mức miễn phí vĩnh viễn" \
      "tổng $TONG_R RCU / $TONG_W WCU (trần 25/25, tính CẢ chỉ mục)"
  else
    fail "capacity provisioned nằm trong hạn mức miễn phí vĩnh viễn" \
      "tổng <= 25 RCU và <= 25 WCU, tính cả chỉ mục phụ" \
      "$TONG_R RCU / $TONG_W WCU"
  fi
fi

echo
echo "  chi phí bạn khai: $CHI_PHI"

summary

cat <<'EOF'

Hai câu tự hỏi trước khi mở DOI-CHIEU.md:

  1. verify.sh chứng minh được rằng khoá sắp xếp của bạn CÓ THỨ TỰ và lọc được
     theo khoảng. Nó KHÔNG chứng minh được rằng thứ tự đó là thứ tự THỜI GIAN —
     nó không biết đâu là "mới". Mở dữ liệu ra và tự kiểm: nếu hai đơn được tạo
     cách nhau một giây, khoá sắp xếp của bạn có phân biệt được không? Nếu bạn
     dùng chuỗi ngày tháng, nó có sắp xếp đúng khi qua năm mới không?

  2. Bạn vừa thêm một chỉ mục phụ để trả lời câu hỏi 2. Mỗi lần ghi một đơn
     hàng vào bảng, có bao nhiêu lần ghi thật sự xảy ra và bạn trả tiền cho mấy
     lần? Câu trả lời quyết định con số WCU bạn phải đặt, và nó là lý do "cứ
     thêm chỉ mục cho chắc" là một lời khuyên tồi.
EOF
