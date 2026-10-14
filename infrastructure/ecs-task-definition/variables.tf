# Input variables for ECS Task Definition

variable "aws_region" {
  description = "AWS region to deploy to"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "Name of the ECS cluster (must match LOT-19)"
  type        = string
}

variable "task_family" {
  description = "Name for the task definition family"
  type        = string
  default     = "rsps-server"
}

variable "ecr_repository_url" {
  description = "ECR repository URL from LOT-18"
  type        = string
}

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
  description = "CPU units for the task (256 = 0.25 vCPU, 512 = 0.5 vCPU, 1024 = 1 vCPU)"
  type        = number
  default     = 1024
}

variable "memory" {
  description = "Memory in MB (512, 1024, 2048, 3072, 4096, etc.)"
  type        = number
  default     = 2048
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "prod"
}

# --- Hiscores database wiring (optional) ---
# When true, the container is wired to the RDS hiscores database created by the
# infrastructure/rds stack (which MUST be applied first). When false (the
# default), no DB_* env vars or DB_PASSWORD secret are injected, so the task
# runs exactly as before and the in-game hiscores stay disabled. This keeps the
# always-on task-definition stack safe even after the ephemeral RDS is destroyed.
variable "enable_database" {
  description = "Wire the container to the RDS hiscores DB (requires infrastructure/rds applied first)"
  type        = bool
  default     = false
}

variable "db_name" {
  description = "Hiscores database name (must match the RDS stack's db_name)"
  type        = string
  default     = "rsps"
}

variable "db_username" {
  description = "Hiscores database username (must match the RDS stack's db_username)"
  type        = string
  default     = "rspsadmin"
}
