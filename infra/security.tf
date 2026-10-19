resource "aws_security_group" "alb" {

  name_prefix = "${local.name}-alb-"
  description = "Public HTTPS and HTTP redirect"
  vpc_id      = aws_vpc.main.id

}
resource "aws_security_group" "app" {

  name_prefix = "${local.name}-app-"
  description = "App only from ALB; no inbound SSH"
  vpc_id      = aws_vpc.main.id

}
resource "aws_security_group" "db" {

  name_prefix = "${local.name}-db-"
  description = "PostgreSQL only from application instances"
  vpc_id      = aws_vpc.main.id

}
resource "aws_vpc_security_group_ingress_rule" "alb" {

  for_each          = toset(["80", "443"])
  security_group_id = aws_security_group.alb.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = tonumber(each.value)
  to_port           = tonumber(each.value)

}
resource "aws_vpc_security_group_egress_rule" "alb_app" {

  security_group_id            = aws_security_group.alb.id
  referenced_security_group_id = aws_security_group.app.id
  ip_protocol                  = "tcp"
  from_port                    = 8000
  to_port                      = 8000

}
resource "aws_vpc_security_group_ingress_rule" "app" {

  security_group_id            = aws_security_group.app.id
  referenced_security_group_id = aws_security_group.alb.id
  ip_protocol                  = "tcp"
  from_port                    = 8000
  to_port                      = 8000

}
resource "aws_vpc_security_group_egress_rule" "app_https" {

  security_group_id = aws_security_group.app.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443

}
resource "aws_vpc_security_group_egress_rule" "app_db" {

  security_group_id            = aws_security_group.app.id
  referenced_security_group_id = aws_security_group.db.id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432

}
resource "aws_vpc_security_group_ingress_rule" "db" {

  security_group_id            = aws_security_group.db.id
  referenced_security_group_id = aws_security_group.app.id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432

}
resource "aws_iam_role" "app" {

  name_prefix = "${local.name}-ec2-"
  assume_role_policy = jsonencode({
    Version = "2012-10-17", Statement = [{
      Effect = "Allow", Principal = {
        Service = "ec2.amazonaws.com"
      }, Action = "sts:AssumeRole"
    }]
  })

}
resource "aws_iam_role_policy_attachment" "ssm" {

  role       = aws_iam_role.app.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore"

}
resource "aws_iam_role_policy_attachment" "logs" {

  role       = aws_iam_role.app.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/CloudWatchAgentServerPolicy"

}
resource "aws_iam_instance_profile" "app" {
  role = aws_iam_role.app.name
}
resource "aws_iam_role_policy" "app" {

  role = aws_iam_role.app.id
  policy = jsonencode({
    Version = "2012-10-17", Statement = [
      {
        Effect = "Allow", Action = ["s3:GetObject"], Resource = ["${aws_s3_bucket.artifact.arn}/releases/*"]
      },
      {
        Effect = "Allow", Action = ["secretsmanager:GetSecretValue"], Resource = [aws_secretsmanager_secret.app.arn]
      }
    ]
  })

}
resource "aws_iam_role_policy" "bootstrap" {

  count = var.enable_db_bootstrap ? 1 : 0
  role  = aws_iam_role.app.id
  policy = jsonencode({
    Version = "2012-10-17", Statement = [{
      Effect = "Allow", Action = ["secretsmanager:GetSecretValue"], Resource = [aws_db_instance.main.master_user_secret[0].secret_arn]
    }]
  })

}
