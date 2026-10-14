# Three alarms, each wired to the SNS topic so a breach emails you.
# `alarm_actions` fire when it goes into ALARM; `ok_actions` fire on recovery,
# so you also get the "all clear."

# --- 1. High CPU ---
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "rsps-${var.service_name}-high-cpu"
  alarm_description   = "Average CPU utilization over ${var.cpu_alarm_threshold}% for 5 minutes"
  namespace           = "AWS/ECS"
  metric_name         = "CPUUtilization"
  dimensions          = { ClusterName = var.cluster_name, ServiceName = var.service_name }
  statistic           = "Average"
  period              = 60
  evaluation_periods  = 5
  threshold           = var.cpu_alarm_threshold
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
}

# --- 2. Service down: fewer than 1 running task ---
# treat_missing_data = "breaching": if the service stops publishing the metric
# (e.g. it's gone), treat that as down. NOTE: while you keep desired_count = 0
# this alarm will sit in ALARM (correctly — zero tasks are running); it flips to
# OK once a task is up and healthy.
resource "aws_cloudwatch_metric_alarm" "no_running_tasks" {
  alarm_name          = "rsps-${var.service_name}-no-running-tasks"
  alarm_description   = "The service has fewer than 1 running task"
  namespace           = "ECS/ContainerInsights"
  metric_name         = "RunningTaskCount"
  dimensions          = { ClusterName = var.cluster_name, ServiceName = var.service_name }
  statistic           = "Average"
  period              = 60
  evaluation_periods  = 3
  threshold           = 1
  comparison_operator = "LessThanThreshold"
  treat_missing_data  = "breaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
}

# --- 3. Error logs ---
# A metric filter turns a text pattern in the logs into a countable metric...
resource "aws_cloudwatch_log_metric_filter" "errors" {
  name           = "rsps-error-lines"
  log_group_name = var.log_group_name
  pattern        = "ERROR"

  metric_transformation {
    name          = "ErrorLogCount"
    namespace     = "RSPS/Logs"
    value         = "1"
    default_value = "0"
  }
}

# ...and this alarm watches that metric.
resource "aws_cloudwatch_metric_alarm" "error_logs" {
  alarm_name          = "rsps-error-logs"
  alarm_description   = "More than 5 ERROR log lines in 5 minutes"
  namespace           = "RSPS/Logs"
  metric_name         = "ErrorLogCount"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 5
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]
}
