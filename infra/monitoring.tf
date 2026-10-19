resource "aws_cloudwatch_log_group" "app" {
  name              = "/${local.name}/application"
  retention_in_days = 14

}
resource "aws_sns_topic" "alerts" {
  name = "${local.name}-alerts"
}
resource "aws_sns_topic_subscription" "email" {

  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.notification_email

}
resource "aws_cloudwatch_metric_alarm" "unhealthy" {

  alarm_name  = "${local.name}-unhealthy-targets"
  namespace   = "AWS/ApplicationELB"
  metric_name = "UnHealthyHostCount"
  dimensions = {
    LoadBalancer = aws_lb.app.arn_suffix, TargetGroup = aws_lb_target_group.app.arn_suffix
  }
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 2
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "missing"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

}
resource "aws_cloudwatch_metric_alarm" "errors" {

  alarm_name  = "${local.name}-target-5xx"
  namespace   = "AWS/ApplicationELB"
  metric_name = "HTTPCode_Target_5XX_Count"
  dimensions = {
    LoadBalancer = aws_lb.app.arn_suffix
  }
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 2
  threshold           = 5
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]

}
resource "aws_cloudwatch_metric_alarm" "db_storage" {

  alarm_name  = "${local.name}-db-free-storage"
  namespace   = "AWS/RDS"
  metric_name = "FreeStorageSpace"
  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.id
  }
  statistic           = "Minimum"
  period              = 300
  evaluation_periods  = 2
  threshold           = 5368709120
  comparison_operator = "LessThanThreshold"
  alarm_actions       = [aws_sns_topic.alerts.arn]

}
resource "aws_cloudwatch_dashboard" "main" {

  dashboard_name = local.name
  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric", x = 0, y = 0, width = 12, height = 6, properties = {
          title = "Application CPU", region = var.aws_region, period = 60, stat = "Average", metrics = [["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", aws_autoscaling_group.app.name]]
        }
      },
      {
        type = "metric", x = 12, y = 0, width = 12, height = 6, properties = {
          title = "Healthy targets", region = var.aws_region, period = 60, stat = "Minimum", metrics = [["AWS/ApplicationELB", "HealthyHostCount", "LoadBalancer", aws_lb.app.arn_suffix, "TargetGroup", aws_lb_target_group.app.arn_suffix]]
        }
      },
      {
        type = "metric", x = 0, y = 6, width = 12, height = 6, properties = {
          title = "Target response time", region = var.aws_region, period = 60, stat = "p95", metrics = [["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", aws_lb.app.arn_suffix]]
        }
      },
      {
        type = "metric", x = 12, y = 6, width = 12, height = 6, properties = {
          title = "RDS CPU", region = var.aws_region, period = 300, stat = "Average", metrics = [["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", aws_db_instance.main.id]]
        }
      }
    ]
  })

}
resource "aws_budgets_budget" "monthly" {

  name         = "${local.name}-monthly"
  budget_type  = "COST"
  limit_amount = tostring(var.monthly_budget_usd)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"
  notification {

    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.notification_email]

  }

}
