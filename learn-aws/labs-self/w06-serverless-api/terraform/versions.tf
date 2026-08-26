# Cho sẵn. Không cần sửa.
#
# Pin phiên bản để hôm nay và ba tháng nữa `terraform apply` cho ra cùng một
# kết quả. Provider AWS thay đổi liên tục; không pin thì lab tự hỏng theo thời gian.

terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
