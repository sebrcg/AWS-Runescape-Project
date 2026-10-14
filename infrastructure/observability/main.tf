# Observability stack for the RSPS server: a CloudWatch dashboard, alarms, and
# email notifications — all as code. Independent stack, decoupled by name from
# the cluster/service it watches.

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "rsps-server"
      ManagedBy   = "terraform"
      Environment = var.environment
      Component   = "observability"
    }
  }
}

# --- Where alarm notifications go ---
# An SNS topic is a fan-out channel: alarms publish to it, and subscribers
# receive the message. Here the subscriber is an email address. AWS emails a
# one-time confirmation link to that address; you MUST click it before any
# alerts will actually be delivered.
resource "aws_sns_topic" "alerts" {
  name = "rsps-observability-alerts"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}
