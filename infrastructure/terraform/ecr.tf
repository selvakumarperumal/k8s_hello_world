# ==============================================================================
# Terraform EKS Infrastructure - ECR Repository
# ==============================================================================
# Creates an ECR repository for storing Docker images.
# ==============================================================================

resource "aws_ecr_repository" "fastapi" {
  name                 = "${var.project_name}-${var.environment}"
  image_tag_mutability = "MUTABLE"

  # Enable image scanning on push
  image_scanning_configuration {
    scan_on_push = true
  }

  # Enable encryption
  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}"
    Description = "ECR repository for FastAPI Hello World application"
  }
}

# -----------------------------------------------------------------------------
# ECR Lifecycle Policy
# -----------------------------------------------------------------------------
# Automatically clean up old images to save storage costs
resource "aws_ecr_lifecycle_policy" "fastapi" {
  repository = aws_ecr_repository.fastapi.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v"]
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Expire untagged images older than 7 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 7
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
