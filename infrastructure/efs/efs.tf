# --- Security group for the EFS mount targets ---
# Locked down: the only thing allowed to open an NFS connection (TCP 2049) is
# the ECS tasks security group. This is the network boundary protecting saves.
resource "aws_security_group" "efs" {
  name        = "${var.cluster_name}-efs-sg"
  description = "Allow NFS from ECS tasks to the EFS mount targets"
  vpc_id      = data.aws_vpc.main.id

  ingress {
    description     = "NFS from ECS tasks"
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [data.aws_security_group.ecs_tasks.id]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.cluster_name}-efs-sg"
  }
}

# --- The EFS file system itself ---
# Managed, elastic NFS. Encrypted at rest with the default AWS-managed KMS key.
# We pay only for what's stored (a few MB of saves), and unused files age into
# the cheaper Infrequent Access tier automatically.
resource "aws_efs_file_system" "gamedata" {
  creation_token  = "${var.cluster_name}-gamedata"
  encrypted       = true
  throughput_mode = "bursting"

  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }

  tags = {
    Name = "${var.cluster_name}-gamedata"
  }
}

# --- Mount targets: one per private subnet (one per AZ) ---
# A mount target is an elastic network interface inside a subnet that NFS
# clients connect to. A task mounts EFS via the target in its own AZ.
resource "aws_efs_mount_target" "gamedata" {
  count           = length(data.aws_subnets.private.ids)
  file_system_id  = aws_efs_file_system.gamedata.id
  subnet_id       = data.aws_subnets.private.ids[count.index]
  security_groups = [aws_security_group.efs.id]
}

# --- Access point ---
# An access point is an application-specific entry point into the file system.
# It pins a POSIX identity and a root directory, so the container is sandboxed
# to /lotica-data on the EFS and always reads/writes as a known user.
#
# The container runs as root (uid/gid 0 — the eclipse-temurin default), and the
# app writes under /opt/lotica/data, so we use uid/gid 0 here to match.
resource "aws_efs_access_point" "gamedata" {
  file_system_id = aws_efs_file_system.gamedata.id

  posix_user {
    uid = 0
    gid = 0
  }

  root_directory {
    path = "/lotica-data"

    # Created automatically the first time the access point is used.
    creation_info {
      owner_uid   = 0
      owner_gid   = 0
      permissions = "0755"
    }
  }

  tags = {
    Name = "${var.cluster_name}-gamedata-ap"
  }
}
