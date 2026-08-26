# Cho sẵn. Không cần sửa — và KHÔNG ĐƯỢC đổi region hay profile.
#
# default_tags gắn tag vào MỌI resource bạn tạo. Hai tag đó là thứ mà
# `_lib/cleanup.sh` và `scripts/find-orphans.sh` dùng để tìm đồ bỏ quên.
# Gỡ chúng ra là tự tay tháo lưới an toàn của mình.

provider "aws" {
  region  = "us-east-1"
  profile = "lab-builder"

  default_tags {
    tags = {
      lab   = "w05"
      owner = "labs-self"
    }
  }
}

# Dùng khi cần ghép account ID vào tên resource phải duy nhất toàn cầu.
data "aws_caller_identity" "toi" {}
