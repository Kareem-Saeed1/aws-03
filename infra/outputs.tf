output "application_url" {
  value = "https://${local.app_host}"
}
output "static_css_url" {
  value = "https://${local.static_host}/${local.static_hash}/style.css"
}
output "autoscaling_group_name" {
  value = aws_autoscaling_group.app.name
}
output "target_group_arn" {
  value = aws_lb_target_group.app.arn
}
output "db_identifier" {
  value = aws_db_instance.main.id
}
output "app_secret_arn" {
  value = aws_secretsmanager_secret.app.arn
}
output "artifact_bucket" {
  value = aws_s3_bucket.artifact.id
}
output "static_bucket" {
  value = aws_s3_bucket.static.id
}
output "sns_topic_arn" {
  value = aws_sns_topic.alerts.arn
}
output "dashboard_name" {
  value = aws_cloudwatch_dashboard.main.dashboard_name
}
output "bootstrap_access_enabled" {
  value = var.enable_db_bootstrap
}
