provider "aws" {
  region  = var.region
  profile = var.profile

  default_tags {
    tags = {
      Project   = "learn"
      Lab       = "w05-databases"
      ManagedBy = "terraform"
    }
  }
}

data "aws_caller_identity" "current" {}
