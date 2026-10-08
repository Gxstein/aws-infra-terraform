variable "aws_region" {
  description = "AWS region where everything is created"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Prefix used in resource names"
  type        = string
  default     = "aws-infra"
}

variable "environment" {
  description = "Environment name (dev or prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment must be dev or prod."
  }
}

variable "github_repository" {
  description = "GitHub repository (owner/name) allowed to assume the CI/CD role through OIDC"
  type        = string
  default     = "Gxstein/aws-infra-terraform"
}

# ---------- Network ----------

variable "vpc_cidr" {
  description = "CIDR block of the VPC"
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid IPv4 CIDR block."
  }
}

variable "az_count" {
  description = "Number of availability zones (one public and one private subnet per AZ)"
  type        = number
  default     = 2

  validation {
    condition     = var.az_count >= 2 && var.az_count <= 3
    error_message = "az_count must be 2 or 3 (RDS needs subnets in at least two AZs)."
  }
}

variable "allowed_http_cidrs" {
  description = "CIDR blocks allowed to reach the API on port 80"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# ---------- Compute ----------

variable "instance_type" {
  description = "EC2 instance type for the API host"
  type        = string
  default     = "t3.micro"
}

variable "app_image_tag" {
  description = "Container image tag deployed when the instance boots"
  type        = string
  default     = "latest"
}

# ---------- Database ----------

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t4g.micro"
}

variable "db_name" {
  description = "Name of the PostgreSQL database"
  type        = string
  default     = "tasks"
}

variable "db_username" {
  description = "Master user of the PostgreSQL database"
  type        = string
  default     = "app_user"
}

# ---------- Monitoring and cost ----------

variable "alert_email" {
  description = "E-mail that receives CloudWatch alarms and AWS Budgets notifications (confirm the SNS subscription e-mail)"
  type        = string

  validation {
    condition     = can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", var.alert_email))
    error_message = "alert_email must be a valid e-mail address."
  }
}

variable "monthly_budget_usd" {
  description = "Monthly cost limit in USD for the AWS Budgets alert"
  type        = number
  default     = 30
}

# ---------- CI/CD ----------

variable "state_bucket_name" {
  description = "S3 bucket that stores the Terraform state (output of ../bootstrap); the CI role gets access to it"
  type        = string
}
