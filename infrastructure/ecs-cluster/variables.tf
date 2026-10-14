variable "aws_region" {
  description = "AWS region for ECS cluster"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "cluster_name" {
  description = "Name of the ECS cluster"
  type        = string
  default     = "rsps-cluster"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
}

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway for private subnets (costs ~$32/month). Set to false if using public IPs on containers."
  type        = bool
  default     = false
}
