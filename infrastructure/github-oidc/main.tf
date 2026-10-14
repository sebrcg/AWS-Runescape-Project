terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "RSPS-Server"
      ManagedBy   = "Terraform"
      Environment = var.environment
    }
  }
}

# The GitHub OIDC identity provider already exists in this account (it was
# created for the portfolio site). We reference it instead of recreating it —
# an account can only have one provider per URL.
data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}
