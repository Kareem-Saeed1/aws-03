data "aws_ssm_parameter" "ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}
resource "aws_launch_template" "app" {

  name_prefix            = "${local.name}-"
  image_id               = data.aws_ssm_parameter.ami.value
  instance_type          = var.instance_type
  update_default_version = true
  vpc_security_group_ids = [aws_security_group.app.id]
  iam_instance_profile {
    name = aws_iam_instance_profile.app.name
  }
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1

  }
  block_device_mappings {

    device_name = "/dev/xvda"
    ebs {
      volume_size           = 16
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true

    }

  }
  monitoring {
    enabled = true
  }
  user_data = base64encode(templatefile("${path.module}/templates/user-data.sh.tftpl", {

    region       = var.aws_region
    bucket       = aws_s3_bucket.artifact.id
    key          = aws_s3_object.artifact.key
    db_host      = aws_db_instance.main.address
    app_secret   = aws_secretsmanager_secret.app.arn
    admin_secret = aws_db_instance.main.master_user_secret[0].secret_arn
    static_url   = "https://${local.static_host}/${local.static_hash}"
    log_group    = aws_cloudwatch_log_group.app.name

  }))
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${local.name}-app"
    }

  }

}
resource "aws_autoscaling_group" "app" {

  name                      = local.name
  min_size                  = 2
  desired_capacity          = 2
  max_size                  = var.asg_max_size
  vpc_zone_identifier       = aws_subnet.app[*].id
  target_group_arns         = [aws_lb_target_group.app.arn]
  health_check_type         = "ELB"
  health_check_grace_period = 1800
  default_instance_warmup   = 180
  enabled_metrics           = ["GroupDesiredCapacity", "GroupInServiceInstances"]
  launch_template {
    id      = aws_launch_template.app.id
    version = aws_launch_template.app.latest_version

  }
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 100
      max_healthy_percentage = 150
      instance_warmup        = 180

    }

  }
  tag {
    key                 = "Name"
    value               = "${local.name}-app"
    propagate_at_launch = true

  }
  lifecycle {
    ignore_changes = [desired_capacity]
  }
  depends_on = [aws_route_table_association.app, aws_iam_role_policy.app, aws_iam_role_policy_attachment.ssm, aws_iam_role_policy_attachment.logs, aws_secretsmanager_secret_version.app]

}
resource "aws_autoscaling_policy" "cpu" {

  count                  = var.enable_step_scaling ? 0 : 1
  name                   = "cpu-target-tracking"
  autoscaling_group_name = aws_autoscaling_group.app.name
  policy_type            = "TargetTrackingScaling"
  target_tracking_configuration {

    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = var.cpu_target

  }

}
resource "aws_autoscaling_policy" "step_out" {

  count                     = var.enable_step_scaling ? 1 : 0
  name                      = "cpu-step-out"
  autoscaling_group_name    = aws_autoscaling_group.app.name
  policy_type               = "StepScaling"
  adjustment_type           = "ChangeInCapacity"
  estimated_instance_warmup = 180
  step_adjustment {
    metric_interval_lower_bound = 0
    metric_interval_upper_bound = 20
    scaling_adjustment          = 1

  }
  step_adjustment {
    metric_interval_lower_bound = 20
    scaling_adjustment          = 2

  }

}
resource "aws_autoscaling_policy" "step_in" {

  count                     = var.enable_step_scaling ? 1 : 0
  name                      = "cpu-step-in"
  autoscaling_group_name    = aws_autoscaling_group.app.name
  policy_type               = "StepScaling"
  adjustment_type           = "ChangeInCapacity"
  estimated_instance_warmup = 180
  step_adjustment {
    metric_interval_upper_bound = 0
    scaling_adjustment          = -1

  }

}
resource "aws_cloudwatch_metric_alarm" "step_out" {

  count               = var.enable_step_scaling ? 1 : 0
  alarm_name          = "${local.name}-step-out"
  namespace           = "AWS/EC2"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = 60
  evaluation_periods  = 2
  threshold           = 60
  comparison_operator = "GreaterThanThreshold"
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.app.name
  }
  alarm_actions = [aws_autoscaling_policy.step_out[0].arn]

}
resource "aws_cloudwatch_metric_alarm" "step_in" {

  count               = var.enable_step_scaling ? 1 : 0
  alarm_name          = "${local.name}-step-in"
  namespace           = "AWS/EC2"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = 60
  evaluation_periods  = 10
  threshold           = 20
  comparison_operator = "LessThanThreshold"
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.app.name
  }
  alarm_actions = [aws_autoscaling_policy.step_in[0].arn]

}
