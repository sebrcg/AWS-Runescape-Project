# ECS Task Definition - The "instruction manual" for running your container

# Data sources to reference resources from LOT-19 (ECS Cluster)
data "aws_ecs_cluster" "main" {
  cluster_name = var.cluster_name
}

data "aws_iam_role" "ecs_task_execution" {
  name = "${var.cluster_name}-task-execution-role"
}

data "aws_iam_role" "ecs_task" {
  name = "${var.cluster_name}-task-role"
}

# EFS persistence (from the infrastructure/efs stack). Looked up by name so this
# stack stays decoupled from the efs stack's state. The efs stack MUST be applied
# first, or these data sources won't resolve.
data "aws_efs_file_system" "gamedata" {
  creation_token = "${var.cluster_name}-gamedata"
}

data "aws_efs_access_points" "gamedata" {
  file_system_id = data.aws_efs_file_system.gamedata.file_system_id
}

# Optional RDS lookup for the hiscores DB (from the infrastructure/rds stack).
# count = 0 when the feature flag is off, so this stack does NOT depend on RDS
# existing — it plans and applies fine before RDS is created or after it's
# destroyed. Looked up by identifier so the two stacks stay decoupled by name.
data "aws_db_instance" "hiscores" {
  count                  = var.enable_database ? 1 : 0
  db_instance_identifier = "${var.cluster_name}-db"
}

locals {
  # Plain env vars: connection coordinates are not secret.
  db_environment = var.enable_database ? [
    {
      name  = "DB_HOST"
      value = data.aws_db_instance.hiscores[0].address
    },
    {
      name  = "DB_PORT"
      value = tostring(data.aws_db_instance.hiscores[0].port)
    },
    {
      name  = "DB_NAME"
      value = var.db_name
    },
    {
      name  = "DB_USER"
      value = var.db_username
    }
  ] : []

  # The password is pulled from Secrets Manager at container start and never
  # appears in the task definition, Terraform state, or logs. The ":password::"
  # suffix selects the "password" key out of the JSON secret RDS manages, and
  # the empty version fields mean "current version". ECS injects it as the
  # DB_PASSWORD env var inside the container only.
  db_secrets = var.enable_database ? [
    {
      name      = "DB_PASSWORD"
      valueFrom = "${data.aws_db_instance.hiscores[0].master_user_secret[0].secret_arn}:password::"
    }
  ] : []
}

# CloudWatch Log Group for container logs
resource "aws_cloudwatch_log_group" "task" {
  name              = "/ecs/${var.task_family}"
  retention_in_days = var.log_retention_days

  tags = {
    Name        = "${var.task_family}-logs"
    Environment = var.environment
  }
}

# ECS Task Definition - This is the core of LOT-20!
resource "aws_ecs_task_definition" "rsps_server" {
  family                   = var.task_family
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cpu
  memory                   = var.memory

  # IAM roles from LOT-19
  execution_role_arn = data.aws_iam_role.ecs_task_execution.arn
  task_role_arn      = data.aws_iam_role.ecs_task.arn

  # Container definition - the actual Docker container specs
  container_definitions = jsonencode([
    {
      name      = "rsps-server"
      image     = "${var.ecr_repository_url}:latest"
      essential = true

      # Port mappings - expose game ports
      portMappings = [
        {
          containerPort = var.container_port_game
          hostPort      = var.container_port_game
          protocol      = "tcp"
          name          = "game-port"
        },
        {
          containerPort = var.container_port_js5
          hostPort      = var.container_port_js5
          protocol      = "tcp"
          name          = "js5-port"
        }
      ]

      # Environment variables for your Java application. The DB_* vars are
      # appended only when enable_database is true (local.db_environment is []
      # otherwise), so a non-database task looks exactly as it did before.
      environment = concat([
        {
          name  = "JAVA_OPTS"
          value = "-Xmx1536m -Xms1536m"
        },
        {
          name  = "SERVER_PORT"
          value = tostring(var.container_port_game)
        },
        {
          name  = "JS5_PORT"
          value = tostring(var.container_port_js5)
        }
      ], local.db_environment)

      # Secrets are resolved from Secrets Manager by the ECS agent (using the
      # execution role) and injected as env vars in the container only. Empty
      # unless the database is enabled.
      secrets = local.db_secrets

      # Mount the EFS volume where the game reads/writes dynamic data.
      # FILES_PATH resolves to /opt/lotica/data inside the Linux container, so
      # player saves, clans, shops, lottery and logs now land on durable EFS
      # instead of the task's throwaway local filesystem.
      mountPoints = [
        {
          sourceVolume  = "gamedata"
          containerPath = "/opt/lotica/data"
          readOnly      = false
        }
      ]

      # CloudWatch Logs configuration
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.task.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }

      # Health check: probe the game port via bash's /dev/tcp. The image
      # (eclipse-temurin) ships bash but NOT netstat/ss, so a netstat-based
      # check always failed and ECS killed the task in a loop. bash opens a
      # TCP connection to the port and exits non-zero if it can't.
      healthCheck = {
        command     = ["CMD-SHELL", "bash -c 'exec 3<>/dev/tcp/127.0.0.1/${var.container_port_game}' || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 120
      }
    }
  ])

  # EFS volume the container above mounts. Transit encryption (TLS) protects the
  # NFS traffic; IAM authorization means only a task wearing the task role (which
  # the efs stack grants ClientMount/ClientWrite) can attach it; the access point
  # sandboxes the task to /lotica-data on the file system.
  volume {
    name = "gamedata"

    efs_volume_configuration {
      file_system_id     = data.aws_efs_file_system.gamedata.file_system_id
      transit_encryption = "ENABLED"

      authorization_config {
        access_point_id = tolist(data.aws_efs_access_points.gamedata.ids)[0]
        iam             = "ENABLED"
      }
    }
  }

  tags = {
    Name        = "${var.task_family}-task-definition"
    Environment = var.environment
  }
}

# Least-privilege access to the ONE RDS-managed secret. The ECS agent uses the
# EXECUTION role (not the task role) to fetch secrets before the container
# starts, so the permission goes here. Scoped to just this secret's ARN — the
# execution role can't read any other secret in the account. Removed
# automatically when enable_database is false.
resource "aws_iam_role_policy" "execution_db_secret" {
  count = var.enable_database ? 1 : 0
  name  = "${var.task_family}-db-secret-access"
  role  = data.aws_iam_role.ecs_task_execution.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = data.aws_db_instance.hiscores[0].master_user_secret[0].secret_arn
      }
    ]
  })
}
