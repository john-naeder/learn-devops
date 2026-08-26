provider "aws" {
  region  = var.region
  profile = var.profile

  default_tags {
    tags = {
      Project   = "learn"
      Lab       = "w07-decoupling"
      ManagedBy = "terraform"
    }
  }
}

data "aws_caller_identity" "current" {}
