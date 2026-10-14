# EFS persistence stack for the RSPS server.
#
# Fargate tasks are disposable: each restart gets a fresh, empty filesystem,
# so player saves written to /opt/lotica/data vanish. This stack provisions an
# Elastic File System (managed NFS) that any task, in any AZ, can mount over the
# network — giving the game durable storage that outlives individual tasks.
#
# Apply order: this stack must be applied BEFORE the ecs-task-definition stack,
# which looks the EFS file system + access point up by name to mount them.

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
      Project     = "rsps-server"
      ManagedBy   = "terraform"
      Environment = var.environment
    }
  }
}

# --- Look up the network created by the ecs-cluster stack (by tag) ---
# Same pattern the ecs-service stack uses, so the stacks stay decoupled
# (no shared remote state) while still wiring up to the same VPC.

data "aws_vpc" "main" {
  filter {
    name   = "tag:Name"
    values = ["${var.cluster_name}-vpc"]
  }
}

# The private subnets the tasks actually run in — we put one EFS mount target
# in each so a task always has an endpoint in its own Availability Zone.
data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.main.id]
  }

  filter {
    name   = "tag:Name"
    values = ["${var.cluster_name}-private-*"]
  }
}

# The ECS tasks' security group. The EFS mount targets will accept NFS
# connections ONLY from this SG — nothing else in the VPC can reach the files.
data "aws_security_group" "ecs_tasks" {
  vpc_id = data.aws_vpc.main.id

  filter {
    name   = "tag:Name"
    values = ["${var.cluster_name}-ecs-tasks-sg"]
  }
}

# The task role the application assumes at runtime. We grant it EFS client
# access (see iam.tf) because the volume mounts with IAM authorization + TLS.
data "aws_iam_role" "ecs_task" {
  name = "${var.cluster_name}-task-role"
}
