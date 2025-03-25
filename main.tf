provider "aws" {
  region = "us-east-1"
  profile = "font-test-superadmin"
}

# ECR Repositories
resource "aws_ecr_repository" "mysql_db" {
  name = "mysql-db"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "flask_api" {
  name                 = "flask-api"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "streamlit_app" {
  name                 = "streamlit-app"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}
