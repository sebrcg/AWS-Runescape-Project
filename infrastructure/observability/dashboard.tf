# A single-pane dashboard for the service: CPU %, memory %, and running tasks.
# Widgets sit on a 24-column grid (x/y/width/height). Each "metrics" entry is
# [namespace, metric, dimensionName, dimensionValue, ...].
resource "aws_cloudwatch_dashboard" "service" {
  dashboard_name = "rsps-server"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "CPU Utilization (%)"
          region  = var.aws_region
          view    = "timeSeries"
          stat    = "Average"
          period  = 60
          metrics = [["AWS/ECS", "CPUUtilization", "ClusterName", var.cluster_name, "ServiceName", var.service_name]]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "Memory Utilization (%)"
          region  = var.aws_region
          view    = "timeSeries"
          stat    = "Average"
          period  = 60
          metrics = [["AWS/ECS", "MemoryUtilization", "ClusterName", var.cluster_name, "ServiceName", var.service_name]]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title   = "Running Tasks"
          region  = var.aws_region
          view    = "timeSeries"
          stat    = "Average"
          period  = 60
          metrics = [["ECS/ContainerInsights", "RunningTaskCount", "ClusterName", var.cluster_name, "ServiceName", var.service_name]]
        }
      }
    ]
  })
}
