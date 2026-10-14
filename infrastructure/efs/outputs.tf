# Outputs consumed by the ecs-task-definition stack (it looks these up by name)
# and handy for verification.

output "file_system_id" {
  description = "EFS file system ID — mounted by the task definition volume"
  value       = aws_efs_file_system.gamedata.id
}

output "file_system_arn" {
  description = "EFS file system ARN"
  value       = aws_efs_file_system.gamedata.arn
}

output "access_point_id" {
  description = "EFS access point ID — referenced by the task definition volume"
  value       = aws_efs_access_point.gamedata.id
}

output "efs_security_group_id" {
  description = "Security group guarding the EFS mount targets"
  value       = aws_security_group.efs.id
}

output "mount_target_ids" {
  description = "Mount target IDs, one per private subnet/AZ"
  value       = aws_efs_mount_target.gamedata[*].id
}
