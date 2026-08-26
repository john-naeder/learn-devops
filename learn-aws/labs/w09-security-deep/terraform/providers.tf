provider "aws" {
  region  = var.region
  profile = var.profile

  default_tags {
    tags = {
      Project   = "learn"
      Lab       = "w09-security-deep"
      ManagedBy = "terraform"
    }
  }
}

data "aws_caller_identity" "current" {}
