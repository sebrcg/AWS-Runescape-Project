# Terraform configuration for ECS Task Definition
# This defines how your container should run

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# AWS Provider - tells Terraform which region to work in
provider "aws" {
  region = var.aws_region
}
