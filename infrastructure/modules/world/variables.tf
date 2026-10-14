# Inputs for the "world" module.
#
# A module is a reusable bundle of resources. Everything that makes one world
# DIFFERENT from another (its id, its name) — or that the module needs but
# shouldn't look up itself (shared cluster/network/role/EFS ids) — comes in
# through these variables. The root stack (infrastructure/worlds) fills them in,
# once per world, via for_each.

# --- What makes this world unique ---

variable "world_id" {
  description = "Numeric world id, passed to the container as the WORLD_ID env var (1, 2, 3...)"
  type        = number
}

variable "world_name" {
  description = "Short slug for this world (e.g. \"world1\"). Used in resource names and as the EFS root directory."
  type        = string
}

# --- Shared infrastructure, looked up ONCE in the root and passed in ---
# The module never queries AWS for these itself: that keeps it pure and reusable,
# and avoids every world re-running the same data lookups.

variable "cluster_id" {
  description = "ECS cluster id/ARN the service runs in"
  type        = string
}

variable "cluster_name" {
  description = "ECS cluster name, used as a prefix for this world's resource names"
  type        = string
}

variable "ecr_repository_url" {
  description = "ECR repository URL for the server image (without the tag)"
  type        = string
}

variable "efs_file_system_id" {
  description = "Id of the shared EFS file system; this world gets its own access point on it"
  type        = string
}

variable "task_execution_role_arn" {
  description = "IAM role ECS uses to START the task (pull image, write logs)"
  type        = string
}

variable "task_role_arn" {
  description = "IAM role the application assumes at RUNTIME (mount EFS)"
  type        = string
}

variable "subnet_ids" {
  description = "Subnets the task's network interface is placed in"
  type        = list(string)
}

variable "security_group_id" {
  description = "Security group applied to the task ENI"
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnets to place this world's internet-facing NLB in"
  type        = list(string)
}

variable "vpc_id" {
  description = "VPC id the NLB target group lives in"
  type        = string
}

# --- Knobs with sensible defaults (same values the single-world stack used) ---

variable "container_port_game" {
  description = "Game server port"
  type        = number
  default     = 43594
}

variable "container_port_js5" {
  description = "JS5 server port"
  type        = number
  default     = 43595
}

variable "cpu" {
  description = "Task CPU units (1024 = 1 vCPU)"
  type        = number
  default     = 1024
}

variable "memory" {
  description = "Task memory in MB"
  type        = number
  default     = 2048
}

variable "log_retention_days" {
  description = "CloudWatch log retention for this world"
  type        = number
  default     = 7
}

variable "desired_count" {
  description = "How many tasks to run for this world. DEFAULT 0 disables Fargate compute; NLB and storage charges still apply."
  type        = number
  default     = 0
}

variable "assign_public_ip" {
  description = "Give the task a public IP (needed to reach the internet without a NAT gateway)"
  type        = bool
  default     = true
}

variable "environment" {
  description = "Environment name (dev/staging/prod) for tagging"
  type        = string
  default     = "prod"
}

variable "aws_region" {
  description = "AWS region (used in the container's log configuration)"
  type        = string
  default     = "us-east-1"
}
