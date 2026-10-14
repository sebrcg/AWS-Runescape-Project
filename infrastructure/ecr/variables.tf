variable "aws_region" {
  description = "AWS region for ECR repository"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "repository_name" {
  description = "Name of the ECR repository"
  type        = string
  default     = "rsps-server"
}
