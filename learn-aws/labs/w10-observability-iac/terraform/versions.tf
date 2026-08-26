terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }

  # ------------------------------------------------------------------------
  # BÀI TẬP REMOTE STATE (xem README.md, phần "Chuyển state lên S3")
  #
  # Sau khi chạy `terraform apply -var tao_backend=true` để tạo bucket và
  # bảng khoá, bỏ comment khối dưới đây rồi chạy `terraform init -migrate-state`.
  #
  # Thay <ACCOUNT_ID> bằng số thật — backend KHÔNG cho dùng biến hay biểu thức,
  # nó được đọc trước khi Terraform biết gì về variables. Đây là giới hạn có
  # thật của Terraform và hay làm người mới bối rối.
  #
  # backend "s3" {
  #   bucket         = "w10-tfstate-<ACCOUNT_ID>"
  #   key            = "w10-observability/terraform.tfstate"
  #   region         = "us-east-1"
  #   dynamodb_table = "w10-tflock"
  #   encrypt        = true
  #   profile        = "learn"
  # }
  # ------------------------------------------------------------------------
}
