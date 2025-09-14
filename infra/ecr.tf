# ECR repositories
resource "aws_ecr_repository" "ahtr" {
  name = var.ecs_repo_name
}

resource "aws_ecr_repository" "frontend" {
  name = var.fe_ecr_repo_name
}
