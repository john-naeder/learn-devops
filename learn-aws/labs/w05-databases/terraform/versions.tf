terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    # Đóng gói mã Lambda thành .zip ngay lúc plan, không cần build step riêng.
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }
}
