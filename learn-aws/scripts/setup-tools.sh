#!/usr/bin/env bash
# Cài Terraform, Ansible, AWS CLI v2 cho WSL/Ubuntu.
# Không cần sudo: mọi thứ đi vào ~/.local/bin và ~/.local/aws-cli.
set -euo pipefail

# WSL này không có en_US.UTF-8; Ansible từ chối chạy nếu locale không phải UTF-8.
# C.utf8 luôn có sẵn trên glibc hiện đại.
# Ép cứng, không dùng ${LC_ALL:-...}: môi trường thường đã set sẵn en_US.UTF-8
# (giá trị hỏng) nên toán tử :- sẽ giữ nguyên giá trị hỏng đó.
if ! locale -a 2>/dev/null | grep -qix 'en_US.utf8'; then
  export LC_ALL=C.utf8
  export LANG=C.utf8
fi

BIN="$HOME/.local/bin"
mkdir -p "$BIN"

have() { command -v "$1" >/dev/null 2>&1; }
say()  { printf '\n\033[1m==> %s\033[0m\n' "$*"; }

ARCH=$(uname -m)
case "$ARCH" in
  x86_64)  TF_ARCH=amd64; AWS_ARCH=x86_64 ;;
  aarch64) TF_ARCH=arm64; AWS_ARCH=aarch64 ;;
  *) echo "Kiến trúc không hỗ trợ: $ARCH" >&2; exit 1 ;;
esac

# ---------------------------------------------------------------- Terraform
TF_VERSION="${TF_VERSION:-1.9.8}"
if have terraform; then
  say "Terraform đã có: $(terraform version | head -1)"
else
  say "Cài Terraform $TF_VERSION"
  tmp=$(mktemp -d)
  curl -fsSL -o "$tmp/tf.zip" \
    "https://releases.hashicorp.com/terraform/${TF_VERSION}/terraform_${TF_VERSION}_linux_${TF_ARCH}.zip"
  unzip -q -o "$tmp/tf.zip" -d "$tmp"
  install -m 0755 "$tmp/terraform" "$BIN/terraform"
  rm -rf "$tmp"
fi

# ---------------------------------------------------------------- AWS CLI v2
if have aws; then
  say "AWS CLI đã có: $(aws --version)"
else
  say "Cài AWS CLI v2"
  tmp=$(mktemp -d)
  curl -fsSL -o "$tmp/awscliv2.zip" \
    "https://awscli.amazonaws.com/awscli-exe-linux-${AWS_ARCH}.zip"
  unzip -q -o "$tmp/awscliv2.zip" -d "$tmp"
  "$tmp/aws/install" --install-dir "$HOME/.local/aws-cli" --bin-dir "$BIN" --update
  rm -rf "$tmp"
fi

# -------------------------------------------------- session-manager-plugin
# Cần cho `aws ssm start-session` và cho connection plugin amazon.aws.aws_ssm
# của Ansible. AWS chỉ phát hành dạng .deb; ở đây giải nén thủ công vào
# ~/.local để không cần sudo.
if have session-manager-plugin; then
  say "session-manager-plugin đã có"
else
  say "Cài session-manager-plugin"
  case "$ARCH" in
    x86_64)  SMP_ARCH=64bit ;;
    aarch64) SMP_ARCH=arm64 ;;
  esac
  tmp=$(mktemp -d)
  if curl -fsSL -o "$tmp/smp.deb" \
      "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_${SMP_ARCH}/session-manager-plugin.deb"; then
    dpkg-deb -x "$tmp/smp.deb" "$tmp/x"
    mkdir -p "$HOME/.local/sessionmanagerplugin"
    cp -r "$tmp/x/usr/local/sessionmanagerplugin/." "$HOME/.local/sessionmanagerplugin/"
    ln -sf "$HOME/.local/sessionmanagerplugin/bin/session-manager-plugin" "$BIN/session-manager-plugin"
  else
    echo "  (tải thất bại — bỏ qua; chỉ ảnh hưởng lab tuần 2/3/5)" >&2
  fi
  rm -rf "$tmp"
fi

# ---------------------------------------------------------------- Ansible
# Cài vào venv riêng thay vì `pip --user`: an toàn khi shell đang ở trong một
# virtualenv khác (lúc đó --user bị chặn) và không đụng vào Python hệ thống.
VENV="$HOME/.local/share/ansible-venv"
if have ansible-playbook; then
  say "Ansible đã có: $(ansible --version | head -1)"
else
  say "Cài Ansible + boto3 vào venv riêng ($VENV)"
  python3 -m venv "$VENV"
  "$VENV/bin/pip" install --quiet --upgrade pip
  "$VENV/bin/pip" install --quiet ansible boto3 botocore
  for exe in ansible ansible-playbook ansible-galaxy ansible-doc ansible-inventory ansible-vault ansible-config; do
    ln -sf "$VENV/bin/$exe" "$BIN/$exe"
  done
fi

# ---------------------------------------------------------------- Collections
say "Cài amazon.aws + community.aws collection"
"$BIN/ansible-galaxy" collection install amazon.aws community.aws --upgrade

# ---------------------------------------------------------------- PATH
if ! printf '%s' "$PATH" | grep -q "$BIN"; then
  say "Thêm $BIN vào PATH"
  for rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
    [ -f "$rc" ] && ! grep -q '.local/bin' "$rc" \
      && echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$rc"
  done
  echo "Mở shell mới hoặc chạy: export PATH=\"\$HOME/.local/bin:\$PATH\""
fi

say "Xong. Kiểm tra:"
echo "  terraform version && ansible --version && aws --version"
