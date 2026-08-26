provider "aws" {
  region  = var.region
  profile = var.profile

  default_tags {
    tags = {
      Project   = "learn"
      Lab       = "w04-s3-cloudfront"
      ManagedBy = "terraform"
    }
  }
}

# Provider thứ hai cho bài Cross-Region Replication.
#
# Đây là mẫu "alias provider" — cách duy nhất để một cấu hình Terraform tạo
# tài nguyên ở nhiều region cùng lúc. Nó luôn tồn tại, nhưng bucket phụ chỉ
# được tạo khi var.enable_crr = true.
#
# CẢNH BÁO: bucket ở region thứ hai là thứ bị bỏ quên nhiều nhất. Bạn sẽ không
# bao giờ mở console region đó nữa. `terraform destroy` xoá được cả hai —
# đó là lý do dùng IaC thay vì click chuột.
provider "aws" {
  alias   = "replica"
  region  = var.replica_region
  profile = var.profile

  default_tags {
    tags = {
      Project   = "learn"
      Lab       = "w04-s3-cloudfront"
      ManagedBy = "terraform"
    }
  }
}

data "aws_caller_identity" "current" {}
