terraform {

  required_version = ">= 1.11.0, < 2.0.0"
  backend "s3" {

  }
  required_providers {

    aws = {
      source = "hashicorp/aws", version = "~> 6.0"
    }
    archive = {
      source = "hashicorp/archive", version = "~> 2.7"
    }
    random = {
      source = "hashicorp/random", version = "~> 3.7"
    }

  }

}
provider "aws" {

  region = var.aws_region
  default_tags {
    tags = {
      Project = var.project_name, Environment = "learning", ManagedBy = "Terraform"
    }
  }

}
provider "aws" {

  alias  = "edge"
  region = "us-east-1"
  default_tags {
    tags = {
      Project = var.project_name, Environment = "learning", ManagedBy = "Terraform"
    }
  }

}
data "aws_availability_zones" "available" {
  state = "available"
}
data "aws_caller_identity" "current" {

}
data "aws_partition" "current" {

}
locals {

  azs         = slice(data.aws_availability_zones.available.names, 0, 2)
  name        = var.project_name
  app_host    = "${var.app_subdomain}.${var.domain_name}"
  static_host = "${var.static_subdomain}.${var.domain_name}"
  static_hash = substr(sha256(join("", [for f in sort(tolist(fileset("${path.module}/../app/static", "**"))) : filesha256("${path.module}/../app/static/${f}")])), 0, 12)

}
