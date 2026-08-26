#!/usr/bin/env bash
# Kiểm tra tĩnh toàn bộ labs/ — KHÔNG cần credential AWS, không tạo tài nguyên.
#
#   terraform validate + fmt   trên mọi thư mục terraform/
#   ansible-playbook --syntax-check + kiểm tra FQCN có thật
#   bash -n                    trên mọi script
#
# Chạy trước khi commit, hoặc sau khi sửa lab.
set -uo pipefail

cd "$(dirname "$0")/.."
ROOT=$(pwd)

export PATH="$HOME/.local/bin:$PATH"
if ! locale -a 2>/dev/null | grep -qix 'en_US.utf8'; then
  export LC_ALL=C.utf8 LANG=C.utf8
fi

RED=$'\033[31m'; GRN=$'\033[32m'; YEL=$'\033[33m'; DIM=$'\033[2m'; OFF=$'\033[0m'
loi=0
ok()   { printf '  %s✓%s %s\n' "$GRN" "$OFF" "$1"; }
bad()  { printf '  %s✗%s %s\n' "$RED" "$OFF" "$1"; loi=$((loi+1)); }
skip() { printf '  %s·%s %s\n' "$DIM" "$OFF" "$1"; }

# ---------------------------------------------------------------- Terraform
echo
echo "═══ Terraform ═══"
if ! command -v terraform >/dev/null; then
  skip "terraform chưa cài — bỏ qua (chạy scripts/setup-tools.sh)"
else
  while IFS= read -r d; do
    ten=${d#"$ROOT"/}
    if [ ! -d "$d/.terraform" ]; then
      (cd "$d" && terraform init -backend=false -input=false -no-color >/dev/null 2>&1)
    fi
    if out=$(cd "$d" && terraform validate -no-color 2>&1); then
      if fmtout=$(cd "$d" && terraform fmt -check -no-color 2>&1) && [ -z "$fmtout" ]; then
        ok "$ten"
      else
        bad "$ten — chưa fmt: $(echo "$fmtout" | tr '\n' ' ')"
      fi
    else
      bad "$ten"
      echo "$out" | sed 's/^/      /'
    fi
  done < <(find "$ROOT/labs" -type d \( -name terraform -o -name 'lab-*' \) -not -path '*/.terraform/*' | sort)
fi

# ------------------------------------------------------------------ Ansible
echo
echo "═══ Ansible — cú pháp ═══"
if ! command -v ansible-playbook >/dev/null; then
  skip "ansible chưa cài — bỏ qua"
else
  while IFS= read -r p; do
    ten=${p#"$ROOT"/}
    d=$(dirname "$p")
    if out=$(cd "$d" && ansible-playbook --syntax-check "$(basename "$p")" 2>&1); then
      ok "$ten"
    else
      bad "$ten"
      echo "$out" | grep -v '^\[WARNING\]' | sed 's/^/      /' | head -12
    fi
  done < <(find "$ROOT/labs" -name '*.yml' -path '*/ansible/*' -not -path '*/group_vars/*' \
             -not -path '*/host_vars/*' -not -name 'aws_ec2.yml' | sort)
fi

# ---------------------------------------------- Ansible — FQCN có thật không
#
# Đây là lỗi đã thực sự xảy ra khi viết repo này: s3_sync nằm ở community.aws
# chứ không phải amazon.aws, mà --syntax-check thì không phát hiện sớm.
# Các module AWS bị chia đôi giữa hai collection theo cách khó đoán.
echo
echo "═══ Ansible — FQCN có tồn tại không ═══"
CP=""
for c in "$HOME/.local/share/ansible-venv/lib"/python*/site-packages/ansible_collections \
         "$HOME/.ansible/collections/ansible_collections"; do
  [ -d "$c" ] && CP="$c" && break
done

if [ -z "$CP" ]; then
  skip "không tìm thấy thư mục collection"
else
  # Gom mọi FQCN dạng namespace.collection.module đứng ở vị trí tên module.
  mapfile -t fqcns < <(
    find "$ROOT/labs" -name '*.yml' -path '*/ansible/*' -print0 \
    | xargs -0 grep -hoE '^\s+(amazon|community|ansible)\.[a-z_]+\.[a-z0-9_]+:' 2>/dev/null \
    | tr -d ' :' | sort -u
  )
  for f in "${fqcns[@]}"; do
    ns=${f%%.*}; rest=${f#*.}; coll=${rest%%.*}; mod=${rest#*.}
    # ansible.builtin nằm trong core, không có trên đĩa theo đường dẫn này.
    if [ "$ns.$coll" = "ansible.builtin" ]; then
      command -v ansible-doc >/dev/null && ansible-doc -t module "$f" >/dev/null 2>&1 \
        && ok "$f" || bad "$f — không phải module builtin hợp lệ"
      continue
    fi
    if [ -f "$CP/$ns/$coll/plugins/modules/$mod.py" ]; then
      ok "$f"
    else
      that=$(find "$CP" -path "*/plugins/modules/$mod.py" 2>/dev/null | head -1)
      if [ -n "$that" ]; then
        dung=$(echo "$that" | sed "s|$CP/||; s|/plugins/modules/|.|; s|\.py$||; s|/|.|")
        bad "$f KHÔNG tồn tại — dùng ${YEL}$dung${OFF}"
      else
        bad "$f — không tìm thấy module $mod ở collection nào"
      fi
    fi
  done
fi

# ---------------------------------------------------------------- Shell
echo
echo "═══ Shell ═══"
while IFS= read -r s; do
  ten=${s#"$ROOT"/}
  bash -n "$s" 2>/dev/null && ok "$ten" || { bad "$ten"; bash -n "$s" 2>&1 | sed 's/^/      /'; }
done < <(find "$ROOT" -name '*.sh' -not -path '*/.terraform/*' | sort)

# ---------------------------------------------------------------- Kết luận
echo
if [ "$loi" -eq 0 ]; then
  printf '%sTất cả kiểm tra đều đạt.%s\n' "$GRN" "$OFF"
else
  printf '%s%d vấn đề cần sửa.%s\n' "$RED" "$loi" "$OFF"
fi
exit $(( loi > 0 ))
