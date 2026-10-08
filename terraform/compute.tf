# Latest Amazon Linux 2023 AMI, resolved through the public SSM parameter
data "aws_ssm_parameter" "al2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

# Container stdout/stderr goes here through Docker's awslogs driver
resource "aws_cloudwatch_log_group" "app" {
  name              = local.app_log_group_name
  retention_in_days = 14
}

resource "aws_instance" "app" {
  ami                    = data.aws_ssm_parameter.al2023_ami.value
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public[0].id
  vpc_security_group_ids = [aws_security_group.app.id]
  iam_instance_profile   = aws_iam_instance_profile.app.name
  ebs_optimized          = true # no extra cost on t3 instances

  # No key pair on purpose: shell access is done with SSM Session Manager

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # IMDSv2 only (protects against SSRF credential theft)
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = 16
    encrypted   = true
  }

  user_data = templatefile("${path.module}/templates/user_data.sh.tftpl", {
    region         = var.aws_region
    registry       = split("/", aws_ecr_repository.app.repository_url)[0]
    image          = aws_ecr_repository.app.repository_url
    default_tag    = var.app_image_tag
    log_group      = aws_cloudwatch_log_group.app.name
    parameter_path = "${local.parameter_prefix}/db"
  })
  user_data_replace_on_change = true

  # The bootstrap script reads the database parameters on first boot
  depends_on = [
    aws_ssm_parameter.db_host,
    aws_ssm_parameter.db_name,
    aws_ssm_parameter.db_user,
    aws_ssm_parameter.db_password,
  ]

  tags = {
    Name = "${local.name}-api"
  }
}
