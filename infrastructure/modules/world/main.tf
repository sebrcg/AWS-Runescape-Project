# One independent world: its own EFS access point, log group, task definition,
# and service. Instantiated once per world by the root stack's for_each.

# --- This world's slice of EFS ---
# Each world gets its OWN access point on the shared file system, rooted at its
# own directory (/world1, /world2...). The access point sandboxes the task to
# that directory: a task wearing this access point literally cannot see another
# world's files. Isolation is enforced by AWS at the storage layer, not by app
# convention. uid/gid 0 matches the container (eclipse-temurin runs as root).
resource "aws_efs_access_point" "world" {
  file_system_id = var.efs_file_system_id

  posix_user {
    uid = 0
    gid = 0
  }

  root_directory {
    path = "/${var.world_name}"

    creation_info {
      owner_uid   = 0
      owner_gid   = 0
      permissions = "0755"
    }
  }

  tags = {
    Name  = "${var.cluster_name}-${var.world_name}-ap"
    World = var.world_name
  }
}

# --- This world's CloudWatch log group ---
# Separate stream per world so you can tell which world a log line came from.
resource "aws_cloudwatch_log_group" "world" {
  name              = "/ecs/${var.cluster_name}-${var.world_name}"
  retention_in_days = var.log_retention_days

  tags = {
    Name        = "${var.cluster_name}-${var.world_name}-logs"
    World       = var.world_name
    Environment = var.environment
  }
}

# --- This world's task definition ---
# Same image as every other world. The ONLY per-world differences are the
# WORLD_ID env var, the access point it mounts, and its log group — exactly the
# "build once, configure many" idea from the WORLD_ID code change, now in infra.
resource "aws_ecs_task_definition" "world" {
  family                   = "${var.cluster_name}-${var.world_name}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = var.task_execution_role_arn
  task_role_arn            = var.task_role_arn

  container_definitions = jsonencode([
    {
      name      = "rsps-server"
      image     = "${var.ecr_repository_url}:latest"
      essential = true

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

      environment = [
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
        },
        # The whole point of Milestone 1 + 2: this is what makes the container
        # announce "Starting World #N" and (later) behave per-world.
        {
          name  = "WORLD_ID"
          value = tostring(var.world_id)
        }
      ]

      # Mounted at the same path in every world; the access point decides which
      # real EFS directory that maps to, so the app needs no per-world path.
      mountPoints = [
        {
          sourceVolume  = "gamedata"
          containerPath = "/opt/lotica/data"
          readOnly      = false
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.world.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }

      # bash /dev/tcp probe — the slim image has bash but not netstat/ss.
      healthCheck = {
        command     = ["CMD-SHELL", "bash -c 'exec 3<>/dev/tcp/127.0.0.1/${var.container_port_game}' || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 120
      }
    }
  ])

  volume {
    name = "gamedata"

    efs_volume_configuration {
      file_system_id     = var.efs_file_system_id
      transit_encryption = "ENABLED"

      authorization_config {
        access_point_id = aws_efs_access_point.world.id
        iam             = "ENABLED"
      }
    }
  }

  tags = {
    Name        = "${var.cluster_name}-${var.world_name}-task"
    World       = var.world_name
    Environment = var.environment
  }
}

# --- This world's Network Load Balancer (the stable front door) ---
# Internet-facing, lives in the PUBLIC subnets. Its dns_name never changes, even
# as the task behind it is replaced and gets new IPs — that's what kills the
# ephemeral-IP problem. NLB (Layer 4) forwards raw TCP; the game isn't HTTP, so
# an ALB (Layer 7) would be the wrong tool.
resource "aws_lb" "world" {
  name               = "${var.cluster_name}-${var.world_name}"
  internal           = false
  load_balancer_type = "network"
  subnets            = var.public_subnet_ids

  # With one task in one AZ, let any NLB node reach it regardless of AZ.
  enable_cross_zone_load_balancing = true

  tags = {
    Name        = "${var.cluster_name}-${var.world_name}-nlb"
    World       = var.world_name
    Environment = var.environment
  }
}

# --- Target group: "who is behind the door" ---
# target_type = "ip" because Fargate tasks register by their private IP (awsvpc).
# ECS keeps this list updated automatically (see the load_balancer block below).
# The TCP health check just opens a connection to the game port to prove it's up.
resource "aws_lb_target_group" "world" {
  name        = "${var.cluster_name}-${var.world_name}"
  port        = var.container_port_game
  protocol    = "TCP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    protocol            = "TCP"
    port                = "traffic-port"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    interval            = 30
  }

  tags = {
    Name        = "${var.cluster_name}-${var.world_name}-tg"
    World       = var.world_name
    Environment = var.environment
  }
}

# --- Listener: "traffic on :43594 -> forward to that target group" ---
resource "aws_lb_listener" "world" {
  load_balancer_arn = aws_lb.world.arn
  port              = var.container_port_game
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.world.arn
  }
}

# --- This world's service ---
# Keeps `desired_count` tasks of this world's task definition alive. Because the
# module owns the task definition, we reference it directly (no name lookup).
resource "aws_ecs_service" "world" {
  name            = "${var.cluster_name}-${var.world_name}"
  cluster         = var.cluster_id
  task_definition = aws_ecs_task_definition.world.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [var.security_group_id]
    assign_public_ip = var.assign_public_ip
  }

  # Register each task's IP into this world's target group, so the NLB always
  # points at a live task. ECS adds/removes targets automatically as tasks cycle
  # — this is what keeps the address stable while the tasks stay disposable.
  load_balancer {
    target_group_arn = aws_lb_target_group.world.arn
    container_name   = "rsps-server"
    container_port   = var.container_port_game
  }

  # Give the server time to boot before the NLB starts failing its health check.
  health_check_grace_period_seconds = 180

  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  enable_execute_command = true

  # The listener must exist before the service tries to register targets.
  depends_on = [aws_lb_listener.world]

  tags = {
    Name        = "${var.cluster_name}-${var.world_name}"
    World       = var.world_name
    Environment = var.environment
  }
}
