provider "aws" {
  region  = var.region
  profile = var.profile

  default_tags {
    tags = {
      Project   = "learn"
      Lab       = "w02-vpc-networking"
      ManagedBy = "terraform"
    }
  }
}

data "aws_caller_identity" "current" {}
