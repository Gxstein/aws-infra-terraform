variable "aws_region" {
  description = "AWS region of the state bucket"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Prefix of the bucket name"
  type        = string
  default     = "aws-infra"
}
