output "state_bucket_name" {
  description = "Use this value as bucket in terraform/backend.hcl and as state_bucket_name"
  value       = aws_s3_bucket.state.bucket
}

output "state_bucket_arn" {
  description = "ARN of the state bucket"
  value       = aws_s3_bucket.state.arn
}
