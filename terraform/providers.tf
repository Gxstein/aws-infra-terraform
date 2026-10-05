provider "aws" {
  region = var.aws_region

  # Every resource gets these tags, which makes cost tracking and cleanup easy
  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
      Repository  = "github.com/${var.github_repository}"
    }
  }
}

data "aws_caller_identity" "current" {}

locals {
  name       = "${var.project_name}-${var.environment}"
  account_id = data.aws_caller_identity.current.account_id

  # Created in compute.tf; referenced by name in IAM so the role can be created first
  app_log_group_name = "/${local.name}/app"

  # All runtime configuration for the API lives under this SSM Parameter Store path
  parameter_prefix = "/${local.name}"
}
