# Source file này ở đầu mỗi phiên làm lab:   source env.sh
# Không chạy bằng ./env.sh — phải là `source` thì biến mới vào shell hiện tại.

# --- PATH: terraform + aws + ansible cài trong ~/.local/bin -------------------
case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) export PATH="$HOME/.local/bin:$PATH" ;;
esac

# --- Locale ------------------------------------------------------------------
# WSL này chỉ có C.utf8, không có en_US.UTF-8. Ansible từ chối khởi động nếu
# LC_ALL trỏ tới một locale không tồn tại, nên phải ép về locale thật sự có.
if ! locale -a 2>/dev/null | grep -qix 'en_US.utf8'; then
  export LC_ALL=C.utf8
  export LANG=C.utf8
fi

# --- AWS ---------------------------------------------------------------------
export AWS_PROFILE="${AWS_PROFILE:-learn}"
export AWS_REGION="${AWS_REGION:-us-east-1}"
export AWS_DEFAULT_REGION="$AWS_REGION"

# Ansible đọc collection từ đây, và tắt cảnh báo interpreter cho gọn output.
export ANSIBLE_PYTHON_INTERPRETER=auto_silent
export ANSIBLE_HOST_KEY_CHECKING=False

echo "profile=$AWS_PROFILE  region=$AWS_REGION"
command -v terraform >/dev/null && echo "terraform $(terraform version -json 2>/dev/null | sed -n 's/.*"terraform_version":"\([^"]*\)".*/\1/p')"
command -v ansible   >/dev/null && ansible --version 2>/dev/null | head -1
command -v aws       >/dev/null && aws --version 2>&1
echo
echo "Kiểm tra danh tính:  aws sts get-caller-identity"
echo "Chi tiêu 7 ngày:     ./scripts/cost-check.sh"
echo "Tìm đồ bỏ quên:      ./scripts/find-orphans.sh"
