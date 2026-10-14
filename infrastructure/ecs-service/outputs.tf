# Outputs - Information displayed after deployment

output "service_name" {
  description = "Name of the ECS service"
  value       = aws_ecs_service.rsps_server.name
}

output "service_id" {
  description = "ARN of the ECS service"
  value       = aws_ecs_service.rsps_server.id
}

output "cluster_name" {
  description = "Name of the ECS cluster"
  value       = var.cluster_name
}

output "desired_count" {
  description = "Number of containers running"
  value       = aws_ecs_service.rsps_server.desired_count
}

output "task_definition" {
  description = "Task definition being used"
  value       = data.aws_ecs_task_definition.rsps_server.family
}

output "security_group_id" {
  description = "Security group ID for the service"
  value       = data.aws_security_group.cluster.id
}

output "subnets" {
  description = "Subnets where containers are running"
  value       = data.aws_subnets.private.ids
}

output "next_steps" {
  description = "What to do next"
  value       = <<-EOT
  
  Service deployed successfully!
  
  To find your container's public IP:
  aws ecs list-tasks --cluster ${var.cluster_name} --service-name ${var.service_name} --region ${var.aws_region}
  
  Then get task details:
  aws ecs describe-tasks --cluster ${var.cluster_name} --tasks <TASK_ARN> --region ${var.aws_region}
  
  Connect to your server:
  - Game Port: <PUBLIC_IP>:43594
  - JS5 Port: <PUBLIC_IP>:43595
  
  View logs:
  aws logs tail /ecs/rsps-server --follow --region ${var.aws_region}
  EOT
}
