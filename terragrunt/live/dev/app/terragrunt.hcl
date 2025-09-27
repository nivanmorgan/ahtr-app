include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../../infra"
}

locals {
  # Detect current public IP at apply time for convenient dev DB access
  my_ip = chomp(run_cmd("bash", "-lc", "curl -s https://checkip.amazonaws.com"))
}

inputs = {
  project                    = "ahtr"
  environment                = "dev"
  region                      = "us-west-2"
  repository_id               = "nivanmorgan/ahtr-app"
  branch                      = "develop"
  code_connection_arn         = "arn:aws:codeconnections:us-west-2:428847003703:connection/3316d1d6-da19-4bd6-a7a3-b1823ec05b08"
  enable_backend_pipeline     = true

  # Frontend infra only; pipeline disabled for now
  enable_frontend_pipeline    = false
  frontend_repository_id      = "nivanmorgan/ahtr-ui"
  frontend_branch             = "develop"
  frontend_code_connection_arn = "arn:aws:codeconnections:us-west-2:428847003703:connection/3316d1d6-da19-4bd6-a7a3-b1823ec05b08"

  artifact_bucket_name        = "ahtr-dev-artifacts-gp-bucket"
  images_bucket_name          = "ahtr-dev-images-gp-bucket"
  frontend_bucket_name        = "ahtr-dev-frontend-gp-bucket"

  fe_ecr_repo_name            = "ahtr-ui"

  # Networking: use default VPC if unset
  vpc_id                      = "vpc-0b20bd3efed7d6b83"
  subnet_ids                  = [
    "subnet-00f70b8da96121bcb",
    "subnet-055a293f918608598",
    "subnet-08f684a9012611f93",
    "subnet-0fcc1383801e586a8"
  ]

  # DB credentials (dev)
  db_name                     = "ahtr"
  db_user                     = "ahtr_user"
  db_password                 = "2VXn0bhGdcnseM2JQB50" # temporary dev secret; rotate later
  # Allowlist current IP for dev DB access automatically. Remove when done.
  db_additional_cidrs         = [format("%s/32", local.my_ip)]

  # Align ECR repo with ECS image name so CodeBuild/CodePipeline and ECS use the same backend repo
  ecs_repo_name               = "ahtr-be"
  # Container image to bootstrap service; pipeline will update image on deploy
  container_image             = "428847003703.dkr.ecr.us-west-2.amazonaws.com/ahtr-be:bootstrap"

  # While pipeline/image is being set up, keep ECS scaled to 0
  desired_count               = 0
}
