# ECR repository for container images
resource "aws_ecr_repository" "ahtr" {
  name = var.ecr_repo_name
}
