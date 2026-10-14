# Inputs for the observability stack.

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name for tagging"
  type        = string
  default     = "prod"
}

variable "cluster_name" {
  description = "ECS cluster the monitored service runs in"
  type        = string
  default     = "rsps-cluster"
}

variable "service_name" {
  description = "ECS service to monitor"
  type        = string
  default     = "rsps-service"
}

variable "log_group_name" {
  description = "CloudWatch log group the service writes to (for the error-log alarm)"
  type        = string
  default     = "/ecs/rsps-server"
}

variable "cpu_alarm_threshold" {
  description = "Alarm when average CPU utilization (%) exceeds this for the eval window"
  type        = number
  default     = 80
}

variable "alert_email" {
  description = "Email address that alarm notifications are sent to. NO default — supply at apply time (e.g. -var alert_email=you@example.com). Requires confirming the subscription email AWS sends."
  type        = string
}
