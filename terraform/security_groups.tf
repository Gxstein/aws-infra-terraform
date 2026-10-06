# Least privilege: each rule opens exactly one port to exactly one source.

# ---------- API host ----------

resource "aws_security_group" "app" {
  name        = "${local.name}-app-sg"
  description = "API host: HTTP in, HTTPS and PostgreSQL out"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${local.name}-app-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "app_http" {
  for_each = toset(var.allowed_http_cidrs)

  security_group_id = aws_security_group.app.id
  description       = "HTTP to the API"
  cidr_ipv4         = each.value
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

# HTTPS out is needed for ECR, SSM, CloudWatch Logs and OS package updates.
# No port 22: shell access goes through SSM Session Manager.
resource "aws_vpc_security_group_egress_rule" "app_https" {
  security_group_id = aws_security_group.app.id
  description       = "HTTPS to AWS APIs and package repositories"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "app_to_db" {
  security_group_id            = aws_security_group.app.id
  description                  = "PostgreSQL to the database"
  referenced_security_group_id = aws_security_group.db.id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
}

# ---------- Database ----------

resource "aws_security_group" "db" {
  name        = "${local.name}-db-sg"
  description = "PostgreSQL: reachable only from the API security group"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${local.name}-db-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "db_from_app" {
  security_group_id            = aws_security_group.db.id
  description                  = "PostgreSQL from the API host"
  referenced_security_group_id = aws_security_group.app.id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
}
