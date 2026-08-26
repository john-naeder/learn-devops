#!/usr/bin/env bash
# ===========================================================================
# Thư viện chấm điểm dùng chung cho mọi verify.sh trong labs-self/
#
#   source ../_lib/check.sh
#
# Đây là GIAO DIỆN CỐ ĐỊNH. Mười hai lab đã viết theo đúng tên hàm dưới đây,
# nên đổi tên hàm là làm hỏng cả bộ. Thêm hàm mới thì được.
#
#   check_init "<tiêu đề lab>"
#   section "<tên nhóm check>"
#   need_output <ten_output>              -> echo giá trị (dùng trong $( ))
#   ok      <mô tả> <giá trị thực tế>
#   fail    <mô tả> <kỳ vọng> <thực tế>
#   assert_eq       <mô tả> <kỳ vọng> <thực tế>
#   assert_ne       <mô tả> <không_được_bằng> <thực tế>
#   assert_contains <mô tả> <chuỗi con> <chuỗi>
#   assert_cmd_ok   <mô tả> <lệnh...>     -> đạt nếu exit 0
#   assert_cmd_fail <mô tả> <lệnh...>     -> đạt nếu exit KHÁC 0 (negative check)
#   summary                               -> tổng kết, exit 1 nếu có Hỏng
#
# Mọi hàm ở đây CHỈ ĐỌC. Không hàm nào tạo, sửa hay xoá tài nguyên AWS.
# ===========================================================================

# --- Màu --------------------------------------------------------------------
# Tắt màu khi output không phải terminal (ví dụ khi pipe vào tee hoặc file log)
# hoặc khi biến NO_COLOR được đặt — quy ước chung của công cụ dòng lệnh.
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  _C_RED=$'\033[31m'
  _C_GREEN=$'\033[32m'
  _C_YELLOW=$'\033[33m'
  _C_BOLD=$'\033[1m'
  _C_DIM=$'\033[2m'
  _C_OFF=$'\033[0m'
else
  _C_RED='' _C_GREEN='' _C_YELLOW='' _C_BOLD='' _C_DIM='' _C_OFF=''
fi

# --- Bộ đếm -----------------------------------------------------------------
# Khởi tạo ngay khi source, để verify.sh chạy dưới `set -u` không nổ nếu lỡ
# gọi ok/fail trước check_init.
_CHECK_PASS=0
_CHECK_FAIL=0
_CHECK_TITLE=""
_CHECK_TOP_PID=$$

# printf "%-50s" đếm BYTE, không đếm ký tự. Tiếng Việt có dấu là UTF-8 nhiều
# byte nên cột sẽ so le. ${#s} của bash đếm ký tự khi locale là UTF-8, nên tự
# căn lề bằng tay mới thẳng hàng. (Quên `source env.sh` -> locale C -> lại so le,
# nhưng chỉ xấu chứ không sai.)
_check_pad() {
  local s="${1:-}" w="${2:-50}" n
  n=${#s}
  if [ "$n" -ge "$w" ]; then printf '%s' "$s"; else printf '%s%*s' "$s" "$((w - n))" ''; fi
}

_check_rule() {
  printf '%s%s%s\n' "$_C_DIM" "----------------------------------------------------------------------" "$_C_OFF"
}

# need_output chạy trong $( ), tức là trong một subshell. `exit 1` ở đó chỉ
# giết subshell, verify.sh vẫn chạy tiếp với giá trị rỗng. Nên nó bắn tín hiệu
# TERM về tiến trình gốc, và trap dưới đây mới là thứ thật sự dừng cả script.
_check_abort() { exit 1; }

check_init() {
  _CHECK_TITLE="${1:-Kiểm tra}"
  _CHECK_PASS=0
  _CHECK_FAIL=0
  _CHECK_TOP_PID=$$
  trap '_check_abort' TERM

  printf '\n%s%s%s\n' "$_C_BOLD" "$_CHECK_TITLE" "$_C_OFF"
  _check_rule
}

section() {
  printf '\n%s%s%s\n' "$_C_BOLD" "${1:-}" "$_C_OFF"
}

# --- Tìm thư mục Terraform --------------------------------------------------
# verify.sh có thể đứng ở thư mục lab (có ./terraform) hoặc đã cd vào trong.
# Đặt biến TF_DIR trước khi source để ép thủ công.
_check_tfdir() {
  if [ -n "${TF_DIR:-}" ]; then printf '%s' "$TF_DIR"; return 0; fi
  if [ -d terraform ]; then printf 'terraform'; else printf '.'; fi
}

# need_output <ten_output>
# Dùng: BUCKET=$(need_output bucket_name)
#
# Cái bẫy ở đây, đã bị dính một lần khi viết thư viện này: khi state chưa có
# output nào, `terraform output -raw x` in cảnh báo "No outputs found" ra
# STDOUT (không phải stderr) rồi exit 0. Bắt lỗi bằng `2>/dev/null` + mã thoát
# là bắt trượt, và verify.sh sẽ đem nguyên đoạn cảnh báo đi so sánh.
# Nên phải dò bằng `output -json <ten>` — lệnh đó exit 1 đúng lúc cần.
need_output() {
  local ten="${1:-}" tfdir gia tatca

  tfdir="$(_check_tfdir)"
  tatca="$(terraform -chdir="$tfdir" output -no-color -json 2>/dev/null)"

  if [ -z "$tatca" ] || [ "$tatca" = "{}" ]; then
    _need_output_hong "$ten" "$tfdir" "chua-apply"
  fi

  if ! terraform -chdir="$tfdir" output -no-color -json "$ten" >/dev/null 2>&1; then
    _need_output_hong "$ten" "$tfdir" "thieu-output"
  fi

  gia="$(terraform -chdir="$tfdir" output -no-color -raw "$ten" 2>/dev/null)"

  case "$gia" in
  "" | *"No outputs found"*) _need_output_hong "$ten" "$tfdir" "thieu-output" ;;
  esac

  printf '%s' "$gia"
}

_need_output_hong() {
  local ten="${1:-}" tfdir="${2:-.}" ly_do="${3:-}"
  {
    printf '\n  %s✗%s chưa apply / thiếu output %s%s%s\n\n' \
      "$_C_RED" "$_C_OFF" "$_C_BOLD" "$ten" "$_C_OFF"

    if [ "$ly_do" = "chua-apply" ]; then
      printf '    State chưa có output nào — hạ tầng chưa được dựng.\n\n'
      printf '      cd %s && terraform init && terraform apply\n\n' "$tfdir"
    else
      printf '    Hạ tầng đã dựng, nhưng không có output tên "%s".\n' "$ten"
      printf '    verify.sh đọc hạ tầng qua Hợp đồng output ghi trong README —\n'
      printf '    đó là giao diện bắt buộc, không phải gợi ý. Khai báo output này\n'
      printf '    trong outputs.tf rồi apply lại.\n\n'
      printf '    Xem mình đang có những output nào:\n'
      printf '      terraform -chdir=%s output\n\n' "$tfdir"
    fi
  } >&2

  kill -TERM "$_CHECK_TOP_PID" 2>/dev/null
  exit 1
}

# --- Hai viên gạch: ok / fail ----------------------------------------------
ok() {
  _CHECK_PASS=$((_CHECK_PASS + 1))
  printf '  %s✓%s %s %s%s%s\n' \
    "$_C_GREEN" "$_C_OFF" "$(_check_pad "${1:-}")" "$_C_DIM" "${2:-}" "$_C_OFF"
}

fail() {
  _CHECK_FAIL=$((_CHECK_FAIL + 1))
  printf '  %s✗%s %s\n' "$_C_RED" "$_C_OFF" "${1:-}"
  printf '      mong đợi : %s\n' "${2:-<không nêu>}"
  printf '      nhận được: %s\n' "${3:-<rỗng>}"
}

# --- Assert -----------------------------------------------------------------
assert_eq() {
  local mota="${1:-}" mong="${2:-}" thuc="${3:-}"
  if [ "$thuc" = "$mong" ]; then ok "$mota" "$thuc"; else fail "$mota" "$mong" "$thuc"; fi
}

assert_ne() {
  local mota="${1:-}" cam="${2:-}" thuc="${3:-}"
  if [ "$thuc" != "$cam" ]; then ok "$mota" "$thuc"; else fail "$mota" "khác \"$cam\"" "$thuc"; fi
}

assert_contains() {
  local mota="${1:-}" con="${2:-}" chuoi="${3:-}"
  case "$chuoi" in
  *"$con"*) ok "$mota" "$chuoi" ;;
  *) fail "$mota" "có chứa \"$con\"" "$chuoi" ;;
  esac
}

# assert_cmd_ok <mô tả> <lệnh...>   — đạt nếu lệnh exit 0
assert_cmd_ok() {
  local mota="${1:-}" rc
  shift
  if "$@" >/dev/null 2>&1; then
    ok "$mota" "exit 0"
  else
    rc=$?
    fail "$mota" "lệnh chạy được (exit 0)" "exit $rc"
  fi
}

# assert_cmd_fail <mô tả> <lệnh...>  — đạt nếu lệnh exit KHÁC 0
#
# Đây là negative check: chứng minh thứ ĐÁNG LẼ bị chặn thì bị chặn thật.
# Một lab chỉ có positive check không chứng minh được gì về bảo mật — bucket
# public cũng "đọc được file" y như bucket đã khoá đúng.
#
# Output của lệnh bị nuốt hoàn toàn: lệnh ở đây được kỳ vọng là sẽ lỗi, nên
# stderr của nó là tiếng ồn, không phải thông tin.
assert_cmd_fail() {
  local mota="${1:-}" rc
  shift
  if "$@" >/dev/null 2>&1; then
    fail "$mota" "bị từ chối (exit khác 0)" "lệnh chạy được — chưa bị chặn"
  else
    rc=$?
    ok "$mota" "bị từ chối (exit $rc)"
  fi
}

# check_failures -> in ra số check đang hỏng.
# Dùng khi cần rẽ nhánh giữa chừng: ví dụ guard.sh không muốn chạy các bước
# tra cứu tốn tiền nếu danh tính đã sai ngay từ đầu.
check_failures() { printf '%s' "$_CHECK_FAIL"; }

# --- Tổng kết ---------------------------------------------------------------
# Trả về 0 khi sạch, để verify.sh in tiếp phần câu hỏi tự vấn.
# Exit 1 ngay khi có check hỏng.
summary() {
  printf '\n'
  _check_rule

  if [ $((_CHECK_PASS + _CHECK_FAIL)) -eq 0 ]; then
    printf '%sKhông có check nào chạy.%s verify.sh đang hỏng, không phải bài của bạn.\n' \
      "$_C_YELLOW" "$_C_OFF"
    exit 1
  fi

  if [ "$_CHECK_FAIL" -eq 0 ]; then
    printf '%sĐạt: %d   Hỏng: 0%s\n' "$_C_GREEN$_C_BOLD" "$_CHECK_PASS" "$_C_OFF"
    return 0
  fi

  printf '%sĐạt: %d   Hỏng: %d%s\n' "$_C_RED$_C_BOLD" "$_CHECK_PASS" "$_CHECK_FAIL" "$_C_OFF"
  printf '\n'
  printf 'Đọc lại từng dòng ✗ ở trên: nó nói rõ mong đợi gì và nhận được gì.\n'
  printf 'Nếu lỗi là AccessDenied, phân biệt hai khả năng trước khi sửa code:\n'
  printf '  - hàng rào chặn  -> thông điệp nhắc tới permissions boundary\n'
  printf '  - bài của bạn sai -> thông điệp nhắc tới policy/role bạn tự viết\n'
  printf 'Chi tiết: labs-self/_boundary/README.md, mục "Đọc lỗi AccessDenied".\n'
  exit 1
}
