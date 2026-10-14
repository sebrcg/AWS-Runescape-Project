# Inputs for the worlds stack.

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

variable "ecr_repository_url" {
  description = "ECR repository URL for the server image (without tag). Contains the AWS account id, so it has NO default and is NOT committed — supply it at plan/apply time with -var or a local (gitignored) tfvars file."
  type        = string
}

variable "environment" {
  description = "Environment name (dev/staging/prod) for tagging"
  type        = string
  default     = "prod"
}

variable "desired_count" {
  description = "Tasks to run PER world. Keep at 0 to define all the infrastructure without running billable Fargate tasks (NLBs and storage still incur charges); raise a world to 1 when you want it live."
  type        = number
  default     = 0
}

# The list of worlds. Adding a world is a one-line change here.
variable "worlds" {
  description = "Map of worlds to create: key = slug (also the EFS directory), value = { id }"
  type = map(object({
    id = number
  }))
  default = {
    world1 = { id = 1 }
    world2 = { id = 2 }
  }
}
