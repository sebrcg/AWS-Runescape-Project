# ECS Service - The production manager that runs and maintains containers

# Data sources - reference resources from LOT-19 and LOT-20
data "aws_ecs_cluster" "main" {
  cluster_name = var.cluster_name
}

data "aws_ecs_task_definition" "rsps_server" {
  task_definition = var.task_definition_family
}

# Get VPC info from LOT-19
data "aws_vpc" "main" {
  filter {
    name   = "tag:Name"
    values = ["${var.cluster_name}-vpc"]
  }
}

# Get private subnets from LOT-19
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

# Get security group from LOT-19
data "aws_security_group" "cluster" {
  vpc_id = data.aws_vpc.main.id

  filter {
    name   = "tag:Name"
    values = ["${var.cluster_name}-ecs-tasks-sg"]
  }
}

# ECS Service - This is LOT-21!
resource "aws_ecs_service" "rsps_server" {
  name            = var.service_name
  cluster         = data.aws_ecs_cluster.main.id
  task_definition = data.aws_ecs_task_definition.rsps_server.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  # Network configuration
  network_configuration {
    subnets          = data.aws_subnets.private.ids
    security_groups  = [data.aws_security_group.cluster.id]
    assign_public_ip = var.assign_public_ip
  }

  # Deployment configuration (these are top-level arguments, not a block)
  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  # Enable ECS Exec for debugging (optional but useful)
  enable_execute_command = true

  tags = {
    Name        = var.service_name
    Environment = var.environment
  }
}
