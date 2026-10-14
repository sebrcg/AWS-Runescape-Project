# Input variables for the EFS persistence stack.

variable "aws_region" {
  description = "AWS region to deploy to"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "Name of the ECS cluster (must match the ecs-cluster stack)"
  type        = string
  default     = "rsps-cluster"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "prod"
}
