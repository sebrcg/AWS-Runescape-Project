# Input variables for ECS Service

variable "aws_region" {
  description = "AWS region to deploy to"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "Name of the ECS cluster (from LOT-19)"
  type        = string
}

variable "service_name" {
  description = "Name for the ECS service"
  type        = string
  default     = "rsps-service"
}

variable "task_definition_family" {
  description = "Task definition family name (from LOT-20)"
  type        = string
  default     = "rsps-server"
}

variable "desired_count" {
  description = "Number of containers to run"
  type        = number
  default     = 0
}

variable "assign_public_ip" {
  description = "Assign public IP to containers (needed for internet access without NAT)"
  type        = bool
  default     = true
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "prod"
}
