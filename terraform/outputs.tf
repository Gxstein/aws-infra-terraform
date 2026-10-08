output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "Public subnets (one per AZ)"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Private subnets (one per AZ)"
  value       = aws_subnet.private[*].id
}

output "ecr_repository_name" {
  description = "ECR repository name (GitHub variable ECR_REPOSITORY)"
  value       = aws_ecr_repository.app.name
}

output "ecr_repository_url" {
  description = "Full ECR repository URL"
  value       = aws_ecr_repository.app.repository_url
}

output "db_endpoint" {
  description = "Private DNS name of the PostgreSQL instance"
  value       = aws_db_instance.main.address
}

output "instance_id" {
  description = "ID of the API host (GitHub variable INSTANCE_ID)"
  value       = aws_instance.app.id
}

output "api_url" {
  description = "Public URL of the API"
  value       = "http://${aws_instance.app.public_dns}"
}

output "ssm_session_command" {
  description = "Opens a shell on the API host without SSH"
  value       = "aws ssm start-session --target ${aws_instance.app.id} --region ${var.aws_region}"
}

output "alerts_topic_arn" {
  description = "SNS topic that receives CloudWatch alarms"
  value       = aws_sns_topic.alerts.arn
}

output "github_actions_role_arn" {
  description = "IAM role assumed by GitHub Actions (GitHub variable AWS_ROLE_ARN)"
  value       = aws_iam_role.github_actions.arn
}
