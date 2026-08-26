provider "aws" {
  region  = var.region
  profile = var.profile

  # default_tags gắn tag vào MỌI resource mà provider tạo ra, không cần nhớ
  # thêm tag ở từng resource. Tag Project=learn là thứ cho phép bạn dùng
  # Tag Editor / Resource Groups để quét sạch tài nguyên khi cần.
  default_tags {
    tags = {
      Project   = "learn"
      Lab       = "w01-iam-foundations"
      ManagedBy = "terraform"
    }
  }
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}
