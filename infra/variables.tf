variable "aws_region" {
  type = string
}
variable "project_name" {

  type    = string
  default = "scalable-webapp"
  validation {

    condition     = can(regex("^[a-z][a-z0-9-]{2,19}$", var.project_name))
    error_message = "Use 3-20 lowercase letters, digits or hyphens, starting with a letter."

  }

}
variable "domain_name" {
  type = string
}
variable "hosted_zone_id" {
  type = string
}
variable "app_subdomain" {
  type    = string
  default = "app"
}
variable "static_subdomain" {
  type    = string
  default = "static"
}
variable "notification_email" {
  type = string
}
variable "vpc_cidr" {
  type    = string
  default = "10.40.0.0/16"
}
variable "instance_type" {
  type    = string
  default = "t3.small"
}
variable "db_instance_class" {
  type    = string
  default = "db.t3.micro"
}
variable "postgres_major_version" {
  type    = string
  default = "16"
}
variable "asg_max_size" {

  type    = number
  default = 4
  validation {

    condition     = var.asg_max_size >= 2
    error_message = "Maximum capacity must be at least two."

  }

}
variable "cpu_target" {
  type    = number
  default = 50
}
variable "enable_step_scaling" {
  type    = bool
  default = false
}
variable "enable_db_bootstrap" {

  type        = bool
  default     = false
  description = "TEMPORARY: permits instances to read the RDS admin secret for initialization. Disable immediately afterward."

}
variable "deletion_protection" {
  type    = bool
  default = true
}
variable "monthly_budget_usd" {
  type    = number
  default = 200
}
variable "demo_username" {
  type    = string
  default = "learner"
}
