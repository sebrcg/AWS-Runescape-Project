output "db_endpoint" {
  description = "Hostname the app connects to (private — resolvable only inside the VPC)"
  value       = aws_db_instance.rsps.address
}

output "db_port" {
  description = "MySQL port"
  value       = aws_db_instance.rsps.port
}

output "db_name" {
  description = "Initial database name"
  value       = aws_db_instance.rsps.db_name
}

output "db_username" {
  description = "Master username"
  value       = aws_db_instance.rsps.username
}

# The ARN of the Secrets Manager secret RDS created for the master password.
# The ECS task definition will reference this to inject the password as an env
# var at launch (via the execution role), so the app never handles the raw value.
output "master_secret_arn" {
  description = "Secrets Manager secret ARN holding the master password"
  value       = aws_db_instance.rsps.master_user_secret[0].secret_arn
}
