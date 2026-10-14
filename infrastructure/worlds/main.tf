# Worlds stack — stamps out N independent worlds from the ../modules/world module.
#
# This stack OWNS nothing shared: the cluster, VPC, subnets, IAM roles and EFS
# file system are all created by other stacks and looked up here by name (the
# same decoupled pattern the efs/ and ecs-service/ stacks use). It only adds the
# per-world resources (access point + log group + task def + service).
#
# Apply order: ecs-cluster, then efs, then this stack.

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

# --- Shared infrastructure, looked up ONCE and handed to every world ---

data "aws_ecs_cluster" "main" {
  cluster_name = var.cluster_name
}

data "aws_vpc" "main" {
  filter {
    name   = "tag:Name"
    values = ["${var.cluster_name}-vpc"]
  }
}

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

# The public subnets an internet-facing NLB must live in.
data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.main.id]
  }

  filter {
    name   = "tag:Name"
    values = ["${var.cluster_name}-public-*"]
  }
}

data "aws_security_group" "ecs_tasks" {
  vpc_id = data.aws_vpc.main.id

  filter {
    name   = "tag:Name"
    values = ["${var.cluster_name}-ecs-tasks-sg"]
  }
}

data "aws_iam_role" "ecs_task_execution" {
  name = "${var.cluster_name}-task-execution-role"
}

data "aws_iam_role" "ecs_task" {
  name = "${var.cluster_name}-task-role"
}

data "aws_efs_file_system" "gamedata" {
  creation_token = "${var.cluster_name}-gamedata"
}

# --- The for_each: one module instance per entry in var.worlds ---
# Add a world by adding a line to var.worlds. That's the entire change needed to
# go from 2 worlds to 3 — the definition is written once, above and in the module.
module "world" {
  for_each = var.worlds
  source   = "../modules/world"

  # per-world identity
  world_name = each.key
  world_id   = each.value.id

  # shared ids handed down from the lookups above
  cluster_id              = data.aws_ecs_cluster.main.id
  cluster_name            = var.cluster_name
  ecr_repository_url      = var.ecr_repository_url
  efs_file_system_id      = data.aws_efs_file_system.gamedata.file_system_id
  task_execution_role_arn = data.aws_iam_role.ecs_task_execution.arn
  task_role_arn           = data.aws_iam_role.ecs_task.arn
  subnet_ids              = data.aws_subnets.private.ids
  security_group_id       = data.aws_security_group.ecs_tasks.id
  public_subnet_ids       = data.aws_subnets.public.ids
  vpc_id                  = data.aws_vpc.main.id

  # operational knobs (0 tasks by default = no cost until you scale up)
  desired_count = var.desired_count
  environment   = var.environment
  aws_region    = var.aws_region
}
