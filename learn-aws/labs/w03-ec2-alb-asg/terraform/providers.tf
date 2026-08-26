provider "aws" {
  region  = var.region
  profile = var.profile

  default_tags {
    tags = {
      Project   = "learn"
      Lab       = "w03-ec2-alb-asg"
      ManagedBy = "terraform"
    }
  }
}

data "aws_caller_identity" "current" {}
