resource "aws_db_subnet_group" "main" {
  subnet_ids = aws_subnet.db[*].id
}
resource "aws_db_parameter_group" "main" {

  family = "postgres${var.postgres_major_version}"
  parameter {
    name  = "rds.force_ssl"
    value = "1"

  }

}
resource "aws_db_instance" "main" {

  identifier                      = local.name
  engine                          = "postgres"
  engine_version                  = var.postgres_major_version
  instance_class                  = var.db_instance_class
  allocated_storage               = 20
  max_allocated_storage           = 100
  storage_type                    = "gp3"
  storage_encrypted               = true
  db_name                         = "webapp"
  username                        = "dbadmin"
  manage_master_user_password     = true
  multi_az                        = true
  publicly_accessible             = false
  db_subnet_group_name            = aws_db_subnet_group.main.name
  parameter_group_name            = aws_db_parameter_group.main.name
  vpc_security_group_ids          = [aws_security_group.db.id]
  backup_retention_period         = 7
  backup_window                   = "01:00-02:00"
  maintenance_window              = "sun:03:00-sun:04:00"
  auto_minor_version_upgrade      = true
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]
  deletion_protection             = var.deletion_protection
  skip_final_snapshot             = false
  final_snapshot_identifier       = "${local.name}-final-${random_id.suffix.hex}"
  copy_tags_to_snapshot           = true

}
resource "random_password" "db" {
  length  = 40
  special = false

}
resource "random_password" "demo" {
  length  = 32
  special = false

}
resource "random_password" "session" {
  length  = 64
  special = false

}
resource "aws_secretsmanager_secret" "app" {

  name_prefix             = "${local.name}-app-"
  recovery_window_in_days = 7

}
resource "aws_secretsmanager_secret_version" "app" {

  secret_id = aws_secretsmanager_secret.app.id
  secret_string = jsonencode({
    db_username = "webapp_runtime", db_password = random_password.db.result, username = var.demo_username, password = random_password.demo.result, session_key = random_password.session.result
  })

}
