#!/usr/bin/env bash
# Trọng tài của lab tuần 12.
#
# Lab này chấm NỘI DUNG bạn viết ra, không chấm hạ tầng bạn dựng lên. Ba loại
# câu hỏi script đem đi hỏi AWS:
#
#   1. Kho ôn tập được mô hình hoá thế nào, và truy vấn nó có RẺ không. Một
#      đường quét toàn kho rồi lọc cho ra ĐÚNG cùng một kết quả — và vẫn là câu
#      trả lời sai trong bài thi. Nên Count không đủ, phải nhìn ScannedCount.
#   2. Nội dung có đủ hình thù của kiến thức dùng được không: đủ trục so sánh,
#      đủ từ khoá đề, đủ ba lý do loại, đủ trọng số bốn miền. Máy không đọc hộ
#      bạn được, nhưng máy đếm được.
#   3. Giám khảo có thật sự chấm không — kể cả khi câu trả lời SAI, kể cả khi mã
#      câu hỏi không tồn tại — và nó có bị nhốt trong trần quyền không.
#
# Script CHỈ ĐỌC: gọi giám khảo ~40 lần, truy vấn kho vài chục lần, không tạo,
# không sửa, không xoá gì, chạy lại nhiều lần cho cùng kết quả.
set -uo pipefail
cd "$(dirname "$0")" || exit 1
source ../_lib/check.sh

export AWS_PROFILE="${LAB_PROFILE:-lab-builder}"
export AWS_REGION="us-east-1"
export AWS_DEFAULT_REGION="us-east-1"

check_init "Tuần 12 — Biến kiến thức của bạn thành dữ liệu, rồi để máy chấm lại bạn"

KHO=$(need_output bang_on_tap)  || exit 1
IDX=$(need_output chi_muc_mien) || exit 1
GK=$(need_output ham_giam_khao) || exit 1
GIA=$(need_output chi_phi)      || exit 1

TMP=$(mktemp -d "${TMPDIR:-/tmp}/w12-XXXXXX") || exit 1
trap 'rm -rf "$TMP"' EXIT

# DynamoDB TỪ CHỐI ExpressionAttributeNames khai thừa, nên mỗi truy vấn mang
# đúng bộ tên nó dùng — không có một bộ dùng chung.
TEN_PL='{"#pl":"phan_loai"}'
TEN_MI='{"#mn":"mien","#ma":"ma"}'
DEM_Q='join(` `,[to_string(Count),to_string(ScannedCount)])'

# ---------------------------------------------------------------------------
# Công cụ
# ---------------------------------------------------------------------------

trong_so() { case "${1:-}" in D1) echo 30 ;; D2) echo 26 ;; D3) echo 24 ;; D4) echo 20 ;; *) echo 0 ;; esac; }
ten_mien() { case "${1:-}" in D1) echo Secure ;; D2) echo Resilient ;; D3) echo High-Performing ;; D4) echo Cost-Optimized ;; esac; }

# bc <khoa> -> một dòng trong báo cáo phân tích gần nhất
bc() { awk -F'\t' -v k="${1:-}" '$1==k{print $2; f=1} END{if(!f) print ""}' "$TMP/bao_cao.txt" 2>/dev/null; }

# dat <mô tả> <khoa>  — trong báo cáo, "0" là sạch, khác 0 là danh sách item sai
dat() {
  local v
  v=$(bc "${2:-}")
  case "$v" in
  0) ok "${1:-}" "không có item nào sai" ;;
  "") fail "${1:-}" "phân tích chạy được" "không đọc được kho ôn tập" ;;
  *) fail "${1:-}" "0 item sai" "$v" ;;
  esac
}

# truy_van <index|-> <điều kiện khoá> <bộ tên JSON> <giá trị JSON> [tham số thêm...]
truy_van() {
  local idx="${1:-}" dk="${2:-}" tn="${3:-}" gt="${4:-}"
  shift 4
  local args=(--table-name "$KHO" --key-condition-expression "$dk"
    --expression-attribute-names "$tn" --expression-attribute-values "$gt")
  [ "$idx" != "-" ] && args+=(--index-name "$idx")
  aws dynamodb query "${args[@]}" "$@" 2>/dev/null
}

# goi_gk <payload JSON> -> in JSON trả về; exit khác 0 nếu hàm lỗi
goi_gk() {
  local loi
  : >"$TMP/gk.json"
  loi=$(aws lambda invoke --function-name "$GK" --cli-binary-format raw-in-base64-out \
    --payload "${1:-}" "$TMP/gk.json" --query 'FunctionError' --output text 2>/dev/null)
  [ "${loi:-None}" != "None" ] && return 1
  [ -s "$TMP/gk.json" ] || return 1
  cat "$TMP/gk.json"
}

# lay <đường dẫn có chấm> -> đọc từ JSON trả về gần nhất của giám khảo
lay() { python3 "$TMP/soi.py" lay "${1:-}" <"$TMP/gk.json" 2>/dev/null; }

cat >"$TMP/soi.py" <<'PY'
import sys, json
M4 = ("D1", "D2", "D3", "D4")

def g(v):  # bóc một giá trị DynamoDB JSON ra kiểu Python
    if not isinstance(v, dict) or len(v) != 1: return None
    k, x = next(iter(v.items()))
    if k in ("S", "BOOL"): return x
    if k == "L":  return [g(i) for i in x]
    if k == "SS": return list(x)
    if k == "M":  return {a: g(b) for a, b in x.items()}
    return None

def S(x, k): r = g(x.get(k, {})); return r if isinstance(r, str) else ""
def L(x, k): r = g(x.get(k, {})); return [i for i in r if isinstance(i, str)] if isinstance(r, list) else []
def D(x, k): r = g(x.get(k, {})); return {a: b for a, b in r.items() if isinstance(b, str)} if isinstance(r, dict) else {}

OUT = []
def bao(k, v): OUT.append("%s\t%s" % (k, v))
def loi(k, xs): bao(k, "0" if not xs else "%d — %s" % (len(xs), ", ".join(sorted(xs)[:4])))
def vao():
    try: return json.load(sys.stdin)
    except Exception: return {}
che_do = sys.argv[1]
if che_do == "lay":
    d = vao()
    for k in sys.argv[2].split("."):
        d = d.get(k) if isinstance(d, dict) else None
    if d is None: print("")
    elif isinstance(d, bool): print("true" if d else "false")
    elif isinstance(d, (dict, list)): print(json.dumps(d, ensure_ascii=False))
    else: print(d)

elif che_do == "kho":
    t = vao().get("Table") or {}
    def kh(ks):
        d = {k["KeyType"]: k["AttributeName"] for k in ks or []}
        return "%s/%s" % (d.get("HASH", "-"), d.get("RANGE", "-"))
    bao("trang_thai", t.get("TableStatus", "<không tìm thấy kho>"))
    bao("tinh_tien", (t.get("BillingModeSummary") or {}).get("BillingMode", "PROVISIONED"))
    bao("khoa", kh(t.get("KeySchema"))); bao("arn", t.get("TableArn", "-"))
    bao("khoa_index", "".join(kh(i.get("KeySchema")) for i in (t.get("GlobalSecondaryIndexes") or [])
                              if i.get("IndexName") == sys.argv[2]) or "<không có index này>")

elif che_do == "bang":
    it = vao().get("Items", [])
    sai_ma, sai_mien, thieu_truc, it_lc, sai_tk, td_kem = [], [], [], [], [], []
    tong_lc, rieng, tds, hop_le, theo = 0, set(), set(), [], {m: 0 for m in M4}
    for x in it:
        ma = S(x, "ma") or "<thiếu ma>"
        (hop_le if ma.startswith("bang#") else sai_ma).append(ma)
        m = S(x, "mien")
        if m in M4: theo[m] += 1
        else: sai_mien.append(ma)
        td = S(x, "tieu_de")
        if len(td) < 10 or td in tds: td_kem.append(ma)
        tds.add(td)
        lc = L(x, "lua_chon")
        if len(lc) < 2: it_lc.append(ma)
        tong_lc += len(lc); rieng |= set(lc)
        if len(L(x, "truc_so_sanh")) < 3: thieu_truc.append(ma)
        tk = D(x, "tu_khoa_de"); v = list(tk.values())
        if (not lc or set(tk) != set(lc) or len(set(v)) != len(v)
                or any(len(i.strip()) < 8 for i in v)):
            sai_tk.append(ma)
    bao("so_bang", len(it)); bao("tong_lua_chon", tong_lc); bao("lua_chon_rieng", len(rieng))
    loi("sai_ma", sai_ma); loi("sai_mien", sai_mien); loi("thieu_truc", thieu_truc)
    loi("it_lua_chon", it_lc); loi("sai_tu_khoa", sai_tk); loi("tieu_de_kem", td_kem)
    bao("mien_bang", " ".join("%s=%d" % (m, theo[m]) for m in M4)); bao("ma_bang", ",".join(hop_le))

elif che_do == "cauhoi":
    it = vao().get("Items", [])
    co_bang = set(i for i in sys.argv[2].split(",") if i)
    sai_ma, sai_mien, ngan, sai_pa, sai_da, thieu_ld, ld_ngan, lien_ket = ([] for _ in range(8))
    theo, mau, mien_map = {m: 0 for m in M4}, [], []
    for x in it:
        ma = S(x, "ma") or "<thiếu ma>"
        if not ma.startswith("cauhoi#"): sai_ma.append(ma)
        m = S(x, "mien")
        if m in M4: theo[m] += 1; mien_map.append("%s=%s" % (ma, m))
        else: sai_mien.append(ma)
        if len(S(x, "noi_dung").strip()) < 80: ngan.append(ma)
        pa = D(x, "phuong_an")
        if set(pa) != set("ABCD") or any(len(i.strip()) < 15 for i in pa.values()): sai_pa.append(ma)
        da = S(x, "dap_an").strip().upper()
        if da not in ("A", "B", "C", "D"): sai_da.append(ma); continue
        ld = D(x, "ly_do_loai")
        if set(ld) != set("ABCD") - {da}: thieu_ld.append(ma)
        if any(len(i.strip()) < 30 for i in ld.values()): ld_ngan.append(ma)
        if S(x, "bang_lien_quan") not in co_bang: lien_ket.append(ma)
        if len(mau) < 4: mau.append("%s:%s" % (ma, da))
    bao("so_cau", len(it)); bao("mau", " ".join(mau)); bao("mien_map", " ".join(mien_map))
    loi("sai_ma", sai_ma); loi("sai_mien", sai_mien); loi("noi_dung_ngan", ngan)
    loi("sai_phuong_an", sai_pa); loi("sai_dap_an", sai_da); loi("thieu_ly_do", thieu_ld)
    loi("ly_do_ngan", ld_ngan); loi("lien_ket_hong", lien_ket)

elif che_do == "dethi":
    xin = int(sys.argv[2])
    ban = dict(p.split("=", 1) for p in sys.argv[3].split() if "=" in p)
    ds = [i for i in (vao().get("ma_cau_hoi") or []) if isinstance(i, str)]
    w = {"D1": .30, "D2": .26, "D3": .24, "D4": .20}
    dem = {m: sum(1 for i in ds if ban.get(i) == m) for m in M4}
    bao("so_tra_ve", len(ds)); loi("trung_lap", [i for i in set(ds) if ds.count(i) > 1])
    loi("khong_co_that", [i for i in ds if i not in ban])
    bao("phan_bo", " ".join("%s=%d" % (m, dem[m]) for m in M4))
    loi("lech_trong_so", ["%s=%d (đúng ~%.1f)" % (m, dem[m], w[m] * xin)
                          for m in M4 if abs(dem[m] - w[m] * xin) > 1.5])

print("\n".join(OUT))
PY

# ---------------------------------------------------------------------------
section "1. Kho ôn tập, và nó không tính tiền lúc bạn ngủ (yêu cầu 1)"
# ---------------------------------------------------------------------------

aws dynamodb describe-table --table-name "$KHO" --output json 2>/dev/null |
  python3 "$TMP/soi.py" kho "$IDX" >"$TMP/bao_cao.txt" 2>/dev/null

ARN_KHO=$(bc arn)
assert_eq "kho ôn tập tồn tại và sẵn sàng" "ACTIVE" "$(bc trang_thai)"
assert_contains "kho mang đúng tiền tố của lab" "self-w12-" "$KHO"

TT=$(bc tinh_tien)
if [ "$TT" = "PAY_PER_REQUEST" ]; then
  ok "kho tính tiền theo lượt dùng" "$TT"
else
  fail "kho tính tiền theo lượt dùng" "PAY_PER_REQUEST" \
    "${TT:-?} — chế độ đặt trước dung lượng tính tiền THEO GIỜ dù không ai gọi, và permissions boundary không có khoá điều kiện nào chặn được lựa chọn đó. Lỗ của hàng rào, và check này là tầng bắt nó"
fi

assert_eq "khoá của kho đúng hợp đồng dữ liệu" "phan_loai/ma" "$(bc khoa)"

KI=$(bc khoa_index)
if [ "$KI" = "mien/ma" ]; then
  ok "có đường vào thứ hai tra được theo miền" "$IDX: $KI"
else
  fail "có đường vào thứ hai tra được theo miền" \
    "index \"$IDX\" có khoá phân vùng mien và khoá sắp xếp ma" \
    "$KI — thiếu nó thì câu \"cho tôi mọi câu hỏi miền D1\" chỉ trả lời được bằng cách quét toàn kho"
fi

# PHỦ ĐỊNH 1 — một index chỉ tra được bằng khoá của CHÍNH NÓ, không phải khoá
# của kho gốc. Đây là chỗ hay nhầm nhất khi mới dùng secondary index.
assert_cmd_fail "index từ chối truy vấn bằng thuộc tính không phải khoá của nó" \
  aws dynamodb query --table-name "$KHO" --index-name "$IDX" \
  --key-condition-expression '#pl = :v' --expression-attribute-names "$TEN_PL" \
  --expression-attribute-values '{":v":{"S":"BANG"}}'

# ---------------------------------------------------------------------------
section "2. Mười bảng so sánh, do chính bạn viết (yêu cầu 2)"
# ---------------------------------------------------------------------------

truy_van - '#pl = :p' "$TEN_PL" '{":p":{"S":"BANG"}}' --output json |
  python3 "$TMP/soi.py" bang >"$TMP/bao_cao.txt" 2>/dev/null

SO_BANG=$(bc so_bang)
MA_BANG=$(bc ma_bang)

if [ "${SO_BANG:-0}" -ge 10 ] 2>/dev/null; then
  ok "có ít nhất 10 bảng so sánh trong kho" "$SO_BANG bảng — $(bc mien_bang)"
else
  fail "có ít nhất 10 bảng so sánh trong kho" ">= 10 item phan_loai = BANG" \
    "${SO_BANG:-0} — đây là ba giờ ôn tập của buổi lab, không phải phần khởi động"
fi

# ma phải THẬT SỰ là khoá sắp xếp, không phải một thuộc tính thường mang tên đó:
# lấy đúng một item bằng khoá đầy đủ thì không tốn một lượt truy vấn nào.
MA1="${MA_BANG%%,*}"
if [ -n "$MA1" ]; then
  assert_cmd_ok "lấy được đúng một bảng bằng khoá đầy đủ, không cần truy vấn" \
    aws dynamodb get-item --table-name "$KHO" \
    --key "{\"phan_loai\":{\"S\":\"BANG\"},\"ma\":{\"S\":\"$MA1\"}}"
fi

dat "mọi bảng dùng đúng tiền tố khoá sắp xếp bang#" sai_ma
dat "mọi bảng gắn đúng một miền D1..D4" sai_mien
dat "mọi bảng có ít nhất 3 trục so sánh" thieu_truc
dat "mọi bảng so sánh ít nhất 2 lựa chọn" it_lua_chon
dat "mọi bảng có tiêu đề riêng, không trùng nhau" tieu_de_kem
dat "mọi lựa chọn đều có từ khoá đề riêng trỏ về nó" sai_tu_khoa

TONG_LC=$(bc tong_lua_chon)
RIENG_LC=$(bc lua_chon_rieng)
if [ "${TONG_LC:-0}" -ge 28 ] 2>/dev/null && [ "${RIENG_LC:-0}" -ge 24 ] 2>/dev/null; then
  ok "bộ bảng có bề rộng thật, không phải 10 biến thể của một bảng" \
    "$TONG_LC lựa chọn, $RIENG_LC tên khác nhau"
else
  fail "bộ bảng có bề rộng thật, không phải 10 biến thể của một bảng" \
    ">= 28 lựa chọn và >= 24 tên khác nhau" "${TONG_LC:-0} lựa chọn, ${RIENG_LC:-0} tên khác nhau"
fi

# --- Hai đường cho CÙNG một kết quả, và chúng không đắt như nhau ------------
read -r Q_COUNT Q_SCAN < <(truy_van - '#pl = :p' "$TEN_PL" '{":p":{"S":"BANG"}}' \
  --select COUNT --query "$DEM_Q" --output text)
read -r S_COUNT S_SCAN < <(aws dynamodb scan --table-name "$KHO" --select COUNT \
  --filter-expression '#pl = :p' --expression-attribute-names "$TEN_PL" \
  --expression-attribute-values '{":p":{"S":"BANG"}}' --query "$DEM_Q" --output text 2>/dev/null)

assert_eq "hai đường lấy bảng cho ra cùng một kết quả" "${S_COUNT:--}" "${Q_COUNT:--}"

if [ "${Q_SCAN:-0}" -lt "${S_SCAN:-0}" ] 2>/dev/null; then
  ok "đường truy vấn RẺ hơn đường quét cho cùng kết quả đó" "đọc $Q_SCAN item thay vì $S_SCAN"
else
  fail "đường truy vấn RẺ hơn đường quét cho cùng kết quả đó" \
    "ScannedCount của Query nhỏ hơn ScannedCount của Scan" \
    "Query đọc ${Q_SCAN:-?} item, Scan đọc ${S_SCAN:-?} — sơ đồ khoá của bạn đang bắt Query đọc cả kho rồi vứt bớt. Đúng kết quả, sai kiến trúc, và sai cả trong bài thi"
fi

# ---------------------------------------------------------------------------
section "3. Ngân hàng câu hỏi, và ba lý do loại cho ba phương án sai (yêu cầu 3)"
# ---------------------------------------------------------------------------

truy_van - '#pl = :p' "$TEN_PL" '{":p":{"S":"CAUHOI"}}' --output json |
  python3 "$TMP/soi.py" cauhoi "$MA_BANG" >"$TMP/bao_cao.txt" 2>/dev/null

SO_CAU=$(bc so_cau)
MAU=$(bc mau)
bc mien_map >"$TMP/mien_map.txt"

if [ "${SO_CAU:-0}" -ge 20 ] 2>/dev/null; then
  ok "ngân hàng có ít nhất 20 câu hỏi" "$SO_CAU câu"
else
  fail "ngân hàng có ít nhất 20 câu hỏi" ">= 20 item phan_loai = CAUHOI" "${SO_CAU:-0}"
fi

dat "mọi câu dùng đúng tiền tố khoá sắp xếp cauhoi#" sai_ma
dat "mọi câu gắn đúng một miền D1..D4" sai_mien
dat "mọi câu là một tình huống, không phải một câu định nghĩa" noi_dung_ngan
dat "mọi câu có đúng 4 phương án A/B/C/D viết ra hồn" sai_phuong_an
dat "mọi câu có đúng một đáp án đúng" sai_dap_an
dat "mọi câu có đủ LÝ DO LOẠI cho cả ba phương án sai" thieu_ly_do
dat "mọi lý do loại là một câu giải thích, không phải một cái nhãn" ly_do_ngan
dat "mọi câu nối được về một bảng so sánh có thật" lien_ket_hong

# ---------------------------------------------------------------------------
section "4. Phân bổ bám trọng số đề thi (yêu cầu 4)"
# ---------------------------------------------------------------------------

: >"$TMP/gsi.txt"
TONG_GSI=0
for M in D1 D2 D3 D4; do
  read -r C S < <(truy_van "$IDX" '#mn = :m AND begins_with(#ma, :tp)' "$TEN_MI" \
    "{\":m\":{\"S\":\"$M\"},\":tp\":{\"S\":\"cauhoi#\"}}" --select COUNT --query "$DEM_Q" --output text)
  printf '%s %s %s\n' "$M" "${C:-0}" "${S:-0}" >>"$TMP/gsi.txt"
  TONG_GSI=$((TONG_GSI + ${C:-0}))
done

LECH_SCAN=$(awk '$2 != $3 {printf "%s (đọc %s để lấy %s) ", $1, $3, $2}' "$TMP/gsi.txt")
if [ -z "$LECH_SCAN" ]; then
  ok "đếm theo miền là truy vấn chọn lọc, không đọc thừa item nào" "ScannedCount = Count ở cả 4 miền"
else
  fail "đếm theo miền là truy vấn chọn lọc, không đọc thừa item nào" \
    "ScannedCount = Count ở cả 4 miền" \
    "${LECH_SCAN}— begins_with của bạn đang nằm ở bộ lọc chứ không nằm trên khoá sắp xếp, nên bạn đã trả tiền đọc rồi mới bỏ bớt"
fi

assert_eq "đếm qua index khớp với đếm qua kho gốc" "${SO_CAU:-0}" "$TONG_GSI"

if [ "${TONG_GSI:-0}" -ge 4 ] 2>/dev/null; then
  while read -r M C _; do
    W=$(trong_so "$M")
    PCT=$(awk -v c="$C" -v t="$TONG_GSI" 'BEGIN{printf "%.1f", 100*c/t}')
    LECH=$(awk -v p="$PCT" -v w="$W" 'BEGIN{d=p-w; if(d<0)d=-d; printf "%.1f", d}')
    if awk -v d="$LECH" 'BEGIN{exit !(d <= 6.0)}'; then
      ok "$M $(ten_mien "$M") bám trọng số ${W}%" "$C câu = ${PCT}%"
    else
      fail "$M $(ten_mien "$M") bám trọng số ${W}%" "${W}% ± 6 điểm phần trăm" \
        "$C/$TONG_GSI câu = ${PCT}% (lệch ${LECH} điểm) — ôn lệch so với đề là cách mất điểm ở đúng miền nặng nhất"
    fi
  done <"$TMP/gsi.txt"
fi

# ---------------------------------------------------------------------------
section "5. Giám khảo chấm được, và chấm SAI là SAI (yêu cầu 5)"
# ---------------------------------------------------------------------------

if goi_gk '{"che_do":"kiem_ke"}' >/dev/null; then
  ok "giám khảo trả lời được ở chế độ kiểm kê" "$(lay tong_bang) bảng, $(lay tong_cau_hoi) câu"
  assert_eq "kiểm kê của giám khảo khớp số bảng verify tự đếm" "${SO_BANG:-0}" "$(lay tong_bang)"
  assert_eq "kiểm kê của giám khảo khớp số câu verify tự đếm" "${SO_CAU:-0}" "$(lay tong_cau_hoi)"
  assert_eq "kiểm kê theo miền của giám khảo khớp số verify đếm qua index (D1)" \
    "$(awk '$1=="D1"{print $2}' "$TMP/gsi.txt")" "$(lay cau_hoi_theo_mien.D1)"
else
  fail "giám khảo trả lời được ở chế độ kiểm kê" \
    "một đối tượng JSON có tong_bang, tong_cau_hoi, cau_hoi_theo_mien" \
    "hàm lỗi hoặc không trả về gì — gọi tay bằng aws lambda invoke ... /dev/stdout để nhìn thứ nó thật sự trả về"
fi

if [ -z "${MAU:-}" ]; then
  fail "có câu hỏi hợp lệ để đem đi chấm thử" ">= 1 câu có đáp án hợp lệ" \
    "không lấy được câu nào — sửa xong mục 3 rồi chạy lại"
else
  DUNG_HET=0 SAI_HET=0 CO_LY_DO=0 SO_MAU=0 DU_MOT=0
  for CAP in $MAU; do
    MA_CH="${CAP%:*}" DA="${CAP##*:}" SO_DUNG_CAU=0 && SO_MAU=$((SO_MAU + 1))
    for PA in A B C D; do
      goi_gk "{\"che_do\":\"cham\",\"ma_cau_hoi\":\"$MA_CH\",\"tra_loi\":\"$PA\"}" >/dev/null || continue
      KQ=$(lay dung)
      LD=$(lay ly_do_loai)
      if [ "$PA" = "$DA" ]; then
        [ "$KQ" = "true" ] && DUNG_HET=$((DUNG_HET + 1))
      else
        [ "$KQ" = "false" ] && SAI_HET=$((SAI_HET + 1))
        [ "${#LD}" -ge 30 ] && CO_LY_DO=$((CO_LY_DO + 1))
      fi
      [ "$KQ" = "true" ] && SO_DUNG_CAU=$((SO_DUNG_CAU + 1))
    done
    [ "$SO_DUNG_CAU" -eq 1 ] && DU_MOT=$((DU_MOT + 1))
  done

  assert_eq "giám khảo chấm ĐÚNG cho phương án đúng" "$SO_MAU" "$DUNG_HET"
  assert_eq "mỗi câu có đúng MỘT phương án được chấm là đúng" "$SO_MAU" "$DU_MOT"
  # PHỦ ĐỊNH 2 — thứ đáng giá nhất trong cả mục này.
  assert_eq "PHỦ ĐỊNH — giám khảo chấm SAI cho cả ba phương án sai" "$((SO_MAU * 3))" "$SAI_HET"
  assert_eq "mỗi lần chấm sai đều kèm lý do loại thật (>= 30 ký tự)" "$((SO_MAU * 3))" "$CO_LY_DO"
fi

# PHỦ ĐỊNH 3 — mã bịa đặt: phải nói không tìm thấy, không được sập, và tuyệt đối
# không được chấm bừa là đúng.
if goi_gk '{"che_do":"cham","ma_cau_hoi":"cauhoi#khong-he-ton-tai-w12","tra_loi":"A"}' >/dev/null; then
  TT_TIM=$(lay tim_thay)
  TT_DUNG=$(lay dung)
  if [ "$TT_TIM" = "false" ] && [ "$TT_DUNG" != "true" ]; then
    ok "PHỦ ĐỊNH — mã câu hỏi bịa đặt bị trả về là không tìm thấy" "tim_thay = false"
  else
    fail "PHỦ ĐỊNH — mã câu hỏi bịa đặt bị trả về là không tìm thấy" \
      "tim_thay = false và KHÔNG có dung = true" \
      "tim_thay = ${TT_TIM:-<thiếu>}, dung = ${TT_DUNG:-<thiếu>}"
  fi
else
  fail "PHỦ ĐỊNH — mã câu hỏi bịa đặt bị trả về là không tìm thấy" \
    'hàm trả về {"tim_thay": false}' \
    "hàm ném lỗi — dữ liệu vào không tin được là chuyện bình thường, sập vì nó thì không"
fi

# ---------------------------------------------------------------------------
section "6. Bốc được một đề thi thử đúng trọng số (yêu cầu 6)"
# ---------------------------------------------------------------------------

XIN=10
if goi_gk "{\"che_do\":\"de_thi\",\"so_cau\":$XIN}" >/dev/null; then
  python3 "$TMP/soi.py" dethi "$XIN" "$(cat "$TMP/mien_map.txt")" \
    <"$TMP/gk.json" >"$TMP/bao_cao.txt" 2>/dev/null
  assert_eq "xin $XIN câu thì trả về đúng $XIN mã" "$XIN" "$(bc so_tra_ve)"
  dat "đề thi thử không có câu nào lặp lại" trung_lap
  dat "mọi mã trong đề thi thử đều có thật trong ngân hàng" khong_co_that
  dat "đề thi thử vẫn bám trọng số bốn miền" lech_trong_so
  ok "phân bổ của đề vừa bốc" "$(bc phan_bo)"
else
  fail "giám khảo bốc được đề thi thử" \
    "một đối tượng JSON có ma_cau_hoi là danh sách $XIN mã" "hàm lỗi ở chế độ de_thi"
fi

# ---------------------------------------------------------------------------
section "7. Giám khảo chỉ đọc, và bị nhốt trong trần quyền (yêu cầu 7)"
# ---------------------------------------------------------------------------

VAI=$(aws lambda get-function-configuration --function-name "$GK" --query 'Role' --output text 2>/dev/null)
TEN_VAI="${VAI##*/}"
ARN_IDX="${ARN_KHO}/index/${IDX}"

sim() {
  aws iam simulate-principal-policy --policy-source-arn "${1:-}" \
    --action-names "${2:-}" --resource-arns "${3:-}" \
    --query 'EvaluationResults[0].EvalDecision' --output text 2>/dev/null || echo LOI_GOI_API
}

assert_contains "giám khảo chạy dưới một danh tính của lab" "self-w12-" "${TEN_VAI:-<không đọc được>}"

RANH=$(aws iam get-role --role-name "$TEN_VAI" \
  --query 'Role.PermissionsBoundary.PermissionsBoundaryArn' --output text 2>/dev/null)
if [ "${RANH:-None}" = "None" ] || [ -z "${RANH:-}" ]; then
  fail "danh tính của giám khảo mang trần quyền của bộ lab" \
    "permissions_boundary trỏ tới policy/labs-self-boundary" \
    "không có trần quyền nào — nếu apply chạy được mà vẫn thiếu nó thì bạn đang dùng nhầm profile, không phải lab-builder"
else
  assert_contains "danh tính của giám khảo mang trần quyền của bộ lab" \
    "policy/labs-self-boundary" "$RANH"
fi

assert_eq "giám khảo ĐỌC được kho ôn tập" "allowed" "$(sim "$VAI" dynamodb:Query "$ARN_KHO")"
assert_eq "giám khảo ĐỌC được đường vào thứ hai" "allowed" "$(sim "$VAI" dynamodb:Query "$ARN_IDX")"

# PHỦ ĐỊNH 4 và 5 — một máy chấm ghi được vào ngân hàng đề là một máy chấm sửa
# được điểm của chính nó.
assert_ne "PHỦ ĐỊNH — giám khảo KHÔNG ghi được vào kho ôn tập" \
  "allowed" "$(sim "$VAI" dynamodb:PutItem "$ARN_KHO")"
assert_ne "PHỦ ĐỊNH — giám khảo KHÔNG xoá được kho ôn tập" \
  "allowed" "$(sim "$VAI" dynamodb:DeleteTable "$ARN_KHO")"

# ---------------------------------------------------------------------------
section "8. PHỦ ĐỊNH — không gì trong lab này tính tiền theo giờ (yêu cầu 8)"
# ---------------------------------------------------------------------------

if awk -v x="$GIA" 'BEGIN{exit !(x + 0 == 0)}' 2>/dev/null; then
  ok "bản khai chi phí nói 0 USD/giờ" "chi_phi = $GIA"
else
  fail "bản khai chi phí nói 0 USD/giờ" "0" \
    "$GIA — lab này không có chỗ nào tốn tiền theo giờ, nên khai khác 0 nghĩa là bạn đã dựng thêm thứ gì đó"
fi

SO_PC=$(aws lambda list-provisioned-concurrency-configs --function-name "$GK" \
  --query 'length(ProvisionedConcurrencyConfigs)' --output text 2>/dev/null)
assert_eq "giám khảo không đặt trước năng lực (thứ tính tiền cả khi không ai gọi)" "0" "${SO_PC:-0}"

SO_MAY=$(aws ec2 describe-instances \
  --filters "Name=tag:lab,Values=w12" "Name=instance-state-name,Values=pending,running,stopping,stopped" \
  --query 'length(Reservations[].Instances[])' --output text 2>/dev/null)
assert_eq "không có máy chủ nào mang tag lab=w12" "0" "${SO_MAY:-0}"

SO_DAT=$(aws resourcegroupstaggingapi get-resources --tag-filters "Key=lab,Values=w12" \
  --resource-type-filters elasticloadbalancing rds elasticache es \
  --query 'length(ResourceTagMappingList)' --output text 2>/dev/null)
assert_eq "không có cân bằng tải / cơ sở dữ liệu / cache / cụm tìm kiếm nào mang tag lab=w12" \
  "0" "${SO_DAT:-0}"

# ---------------------------------------------------------------------------
if summary; then
  cat <<'EOF'

Hai câu tự hỏi trước khi đọc DOI-CHIEU.md:

  1. verify.sh vừa chứng minh ngân hàng câu hỏi của bạn ĐỦ HÌNH THÙ: đủ số câu,
     đủ ba lý do loại, đủ trọng số bốn miền. Nó không chứng minh được một chữ
     nào trong đó là ĐÚNG. Bạn kiểm tra điều đó bằng cách nào — và ai chấm được
     nội dung, nếu chính bạn vừa là người ra đề?

  2. Giám khảo đọc kho bằng quyền của một danh tính có trần quyền. Nếu ngày mai
     bạn cần nó ghi lại ĐIỂM mỗi lần bạn thi thử, bạn sửa ở đâu? Và điểm đó nên
     nằm chung kho với ngân hàng đề hay phải nằm chỗ khác — vì lý do gì?

Rồi mở DOI-CHIEU.md. Đó là file cuối cùng của mười hai tuần.
EOF
fi
