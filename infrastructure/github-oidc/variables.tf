variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "github_repository" {
  description = "GitHub repository (owner/name) whose Actions may assume the role"
  type        = string
}

variable "subject_claim" {
  description = <<-EOT
    Filter on the OIDC token's `sub` claim, appended after `repo:<owner/name>:`.
    "*" allows any ref in this repo (pull_request, branches, tags). Tighten for
    least privilege, e.g. "pull_request" (only PR runs) or "ref:refs/heads/main".
  EOT
  type        = string
  default     = "*"
}

variable "role_name" {
  description = "Name of the IAM role GitHub Actions assumes"
  type        = string
  default     = "rsps-server-github-actions"
}

variable "pulumi_state_bucket" {
  description = "S3 bucket holding Pulumi state (pulumi preview reads/locks it)"
  type        = string
}

variable "ecr_repository_name" {
  description = "ECR repository the CI/CD workflow builds and pushes to"
  type        = string
  default     = "rsps-server"
}

variable "cluster_name" {
  description = "ECS cluster whose services the deploy step is allowed to roll"
  type        = string
  default     = "rsps-cluster"
}
