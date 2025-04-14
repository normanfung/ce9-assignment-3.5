resource "aws_ecr_repository" "app_repo" {
  name                 = "norman-flask-xray-repo"
  image_tag_mutability = "MUTABLE" # or "IMMUTABLE" for stricter image control
  encryption_configuration {
    encryption_type = "AES256"
  }
  force_delete = true
}

resource "aws_ecr_repository_policy" "csr_policy" {
  repository = aws_ecr_repository.app_repo.name

  policy = jsonencode({
    Version = "2008-10-17"
    Statement = [
      {
        Sid    = "AllowPushPull"
        Effect = "Allow"
        Principal = {
          AWS = "*"
        }
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
      }
    ]
  })
}
