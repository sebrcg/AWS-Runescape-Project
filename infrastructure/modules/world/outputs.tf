# What this module reports back about the world it built. The root stack
# collects these across all worlds; a later stack (NLB/DNS) can consume them.

output "world_name" {
  description = "The world's slug"
  value       = var.world_name
}

output "service_name" {
  description = "Name of this world's ECS service"
  value       = aws_ecs_service.world.name
}

output "task_definition_arn" {
  description = "ARN (with revision) of this world's task definition"
  value       = aws_ecs_task_definition.world.arn
}

output "access_point_id" {
  description = "EFS access point id sandboxing this world to its own directory"
  value       = aws_efs_access_point.world.id
}

output "efs_root_directory" {
  description = "The directory on the EFS file system this world reads/writes"
  value       = "/${var.world_name}"
}

output "log_group" {
  description = "CloudWatch log group for this world"
  value       = aws_cloudwatch_log_group.world.name
}

output "nlb_dns_name" {
  description = "Stable public DNS name of this world's NLB — the address the client connects to"
  value       = aws_lb.world.dns_name
}
