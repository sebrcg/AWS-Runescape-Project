# Grant the ECS task role permission to mount and write the EFS file system.
#
# This is required because the task definition mounts the volume with IAM
# authorization (authorization_config.iam = "ENABLED") and transit encryption
# (TLS). With IAM auth on, EFS checks these permissions on every mount — so even
# inside the VPC, only a task wearing this role can attach the filesystem.
#
# The Condition pins access to our specific access point: this role can only
# mount EFS *through* /lotica-data, not the raw root of the file system.
resource "aws_iam_role_policy" "efs_client" {
  name = "${var.cluster_name}-efs-client"
  role = data.aws_iam_role.ecs_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowEfsClientAccess"
        Effect = "Allow"
        Action = [
          "elasticfilesystem:ClientMount",
          "elasticfilesystem:ClientWrite",
          "elasticfilesystem:ClientRootAccess"
        ]
        Resource = aws_efs_file_system.gamedata.arn
        Condition = {
          StringEquals = {
            "elasticfilesystem:AccessPointArn" = aws_efs_access_point.gamedata.arn
          }
        }
      }
    ]
  })
}
