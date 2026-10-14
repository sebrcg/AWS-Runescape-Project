# Outputs - Information displayed after Terraform creates resources

output "task_definition_arn" {
  description = "Full ARN of the task definition"
  value       = aws_ecs_task_definition.rsps_server.arn
}

output "task_definition_family" {
  description = "Task definition family name"
  value       = aws_ecs_task_definition.rsps_server.family
}

output "task_definition_revision" {
  description = "Task definition revision number"
  value       = aws_ecs_task_definition.rsps_server.revision
}

output "log_group_name" {
  description = "CloudWatch log group name for viewing container logs"
  value       = aws_cloudwatch_log_group.task.name
}

output "container_name" {
  description = "Container name (used in LOT-21)"
  value       = "rsps-server"
}

output "container_port_game" {
  description = "Game server port"
  value       = var.container_port_game
}

output "container_port_js5" {
  description = "JS5 server port"
  value       = var.container_port_js5
}
