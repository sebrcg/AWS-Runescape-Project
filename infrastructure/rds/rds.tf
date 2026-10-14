# --- DB subnet group ---
# Tells RDS which subnets it may place the database in. We give it the PRIVATE
# subnets, so the instance has no route to the internet and can't be reached
# from outside the VPC.
resource "aws_db_subnet_group" "main" {
  name       = "${var.cluster_name}-db-subnet-group"
  subnet_ids = data.aws_subnets.private.ids

  tags = {
    Name = "${var.cluster_name}-db-subnet-group"
  }
}

# --- Security group for the database ---
# The network boundary around the DB: port 3306 (MySQL) is open ONLY to the ECS
# tasks' security group. Not the internet, not the rest of the VPC — only our
# containers can even open a connection.
resource "aws_security_group" "rds" {
  name        = "${var.cluster_name}-rds-sg"
  description = "Allow MySQL from the ECS tasks only"
  vpc_id      = data.aws_vpc.main.id

  ingress {
    description     = "MySQL from ECS tasks"
    from_port       = 3306
    to_port         = 3306
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
    Name = "${var.cluster_name}-rds-sg"
  }
}

# --- The database instance ---
# Managed MySQL. The master password is NOT set here: manage_master_user_password
# makes RDS generate a strong password and store it in AWS Secrets Manager, so it
# never touches Terraform code or state. The app fetches it from there at runtime.
resource "aws_db_instance" "rsps" {
  identifier     = "${var.cluster_name}-db"
  engine         = "mysql"
  engine_version = var.db_engine_version
  instance_class = var.db_instance_class

  allocated_storage = var.db_allocated_storage
  storage_type      = "gp3"
  storage_encrypted = true

  db_name  = var.db_name
  username = var.db_username

  # RDS generates + rotates the master password into Secrets Manager for us.
  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false

  multi_az                = false
  backup_retention_period = 1

  # Demo-friendly: no final snapshot on destroy so teardown is quick.
  skip_final_snapshot = true
  deletion_protection = false

  tags = {
    Name = "${var.cluster_name}-db"
  }
}
