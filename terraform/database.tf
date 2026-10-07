resource "random_password" "db" {
  length  = 32
  special = true
  # RDS does not accept / @ " or spaces in the master password
  override_special = "!#$%^&*()-_=+[]{}<>:?"
}

resource "aws_db_subnet_group" "main" {
  name        = "${local.name}-db-subnets"
  description = "Private subnets for PostgreSQL"
  subnet_ids  = aws_subnet.private[*].id
}

resource "aws_db_instance" "main" {
  identifier     = "${local.name}-postgres"
  engine         = "postgres"
  engine_version = "16"
  instance_class = var.db_instance_class

  # Storage starts at 20 GiB and grows automatically up to 50 GiB
  allocated_storage     = 20
  max_allocated_storage = 50
  storage_type          = "gp3"
  storage_encrypted     = true # encryption at rest with KMS

  db_name  = var.db_name
  username = var.db_username
  password = random_password.db.result

  # Private subnets + security group that only accepts the API host
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.db.id]
  publicly_accessible    = false

  # Single-AZ keeps the lab cheap; switch multi_az on for production
  multi_az                        = var.environment == "prod"
  backup_retention_period         = 1
  auto_minor_version_upgrade      = true
  copy_tags_to_snapshot           = true
  enabled_cloudwatch_logs_exports = ["postgresql"]

  deletion_protection       = var.environment == "prod"
  skip_final_snapshot       = var.environment != "prod"
  final_snapshot_identifier = "${local.name}-postgres-final"
  apply_immediately         = true
}

# ---------- Runtime configuration for the API (SSM Parameter Store) ----------
# The instance reads these at deploy time; the password is a SecureString
# encrypted with KMS (aws/ssm key), so it never appears in user data or in the image.

resource "aws_ssm_parameter" "db_host" {
  name  = "${local.parameter_prefix}/db/host"
  type  = "String"
  value = aws_db_instance.main.address
}

resource "aws_ssm_parameter" "db_name" {
  name  = "${local.parameter_prefix}/db/name"
  type  = "String"
  value = var.db_name
}

resource "aws_ssm_parameter" "db_user" {
  name  = "${local.parameter_prefix}/db/user"
  type  = "String"
  value = var.db_username
}

resource "aws_ssm_parameter" "db_password" {
  name  = "${local.parameter_prefix}/db/password"
  type  = "SecureString"
  value = random_password.db.result
}
