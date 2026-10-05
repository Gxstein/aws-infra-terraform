terraform {
  # Remote state in S3 with native lock file (no DynamoDB table needed).
  # Partial configuration: bucket, key and region come from backend.hcl
  # (copy backend.hcl.example) or from -backend-config flags in CI.
  backend "s3" {}
}
