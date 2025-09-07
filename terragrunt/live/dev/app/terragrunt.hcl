include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../infra"
}

inputs = {
  project                    = "ahtr"
  environment                = "dev"
  region                      = "us-west-2"
  repository_id               = "nivanmorgan/ahtr-app"
  branch                      = "main"
  code_connection_arn         = "arn:aws:codeconnections:us-west-2:428847003703:connection/3316d1d6-da19-4bd6-a7a3-b1823ec05b08"

  # Frontend infra only; pipeline disabled for now
  enable_frontend_pipeline    = false
  frontend_repository_id      = "nivanmorgan/ahtr-ui"
  frontend_branch             = "develop"
  frontend_code_connection_arn = "arn:aws:codeconnections:us-west-2:428847003703:connection/3316d1d6-da19-4bd6-a7a3-b1823ec05b08"

  artifact_bucket_name        = "ahtr-dev-artifacts-gp-bucket"
  images_bucket_name          = "ahtr-dev-images-gp-bucket"
  frontend_bucket_name        = "ahtr-dev-frontend-gp-bucket"

  ecs_repo_name               = "ahtr-repo"
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
  db_password                 = "CHANGE-ME"  # set a real secret locally, not committed

  # Container image to bootstrap service; pipeline will update
  container_image             = "428847003703.dkr.ecr.us-west-2.amazonaws.com/ahtr-be:bootstrap"
}
