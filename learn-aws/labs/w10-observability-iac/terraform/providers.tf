provider "aws" {
  region  = var.region
  profile = var.profile

  default_tags {
    tags = {
      Project   = "learn"
      Lab       = "w10-observability-iac"
      ManagedBy = "terraform"
    }
  }
}

data "aws_caller_identity" "current" {}
