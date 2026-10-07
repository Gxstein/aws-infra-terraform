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
