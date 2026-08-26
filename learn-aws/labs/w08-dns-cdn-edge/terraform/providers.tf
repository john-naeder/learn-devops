provider "aws" {
  region  = var.region
  profile = var.profile

  default_tags {
    tags = {
      Project   = "learn"
      Lab       = "w08-dns-cdn-edge"
      ManagedBy = "terraform"
    }
  }
}

data "aws_caller_identity" "current" {}
