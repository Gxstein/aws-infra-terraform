# Private registry for the API image. CI pushes two tags per build:
# the short commit SHA (immutable history, used for rollback) and "latest".
resource "aws_ecr_repository" "app" {
  name                 = "${local.name}-api"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true # basic vulnerability scan on every push
  }

  encryption_configuration {
    encryption_type = "AES256"
  }
}

# Keeps storage (and cost) small: only the 10 most recent images are kept
resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep only the last 10 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = {
        type = "expire"
      }
    }]
  })
}
