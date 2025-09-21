include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../../infra"
}

inputs = {
  project                      = "ahtr"
  environment                  = "prod"
  region                       = "us-west-2"
  repository_id                = "nivanmorgan/ahtr-app"
  branch                       = "main"
  code_connection_arn          = "arn:aws:codeconnections:us-west-2:428847003703:connection/3316d1d6-da19-4bd6-a7a3-b1823ec05b08"
  enable_backend_pipeline      = true

  # Frontend infra only; enable pipeline when ready
  enable_frontend_pipeline     = false
  frontend_repository_id       = "nivanmorgan/ahtr-ui"
  frontend_branch              = "main"
  frontend_code_connection_arn = "arn:aws:codeconnections:us-west-2:CHANGE-ME-ACCOUNT:connection/CHANGE-ME-CONNECTION"

  artifact_bucket_name         = "ahtr-prod-artifacts-gp-bucket"
  images_bucket_name           = "ahtr-prod-images-gp-bucket"
  frontend_bucket_name         = "ahtr-prod-frontend-gp-bucket"

  ecs_repo_name                = "ahtr-be"
  fe_ecr_repo_name             = "ahtr-ui"

  # Pin to dedicated VPC/subnets for prod (replace with prod-specific values if different)
  vpc_id                      = "vpc-0b20bd3efed7d6b83"
  subnet_ids                  = [
    "subnet-00f70b8da96121bcb",
    "subnet-055a293f918608598",
    "subnet-08f684a9012611f93",
    "subnet-0fcc1383801e586a8"
  ]

  # DB credentials (prod)
  db_name                      = "ahtr"
  db_user                      = "ahtr_user"
  db_password                  = "CHANGE-ME-STRONG"

  # ACM / DNS can be added here later
  # certificate_arn            = "arn:aws:acm:us-west-2:...:certificate/..."
  # domain_name                = "api.example.com"
  # hosted_zone_id             = "Z..."

  container_image              = "428847003703.dkr.ecr.us-west-2.amazonaws.com/ahtr-be:latest"
  enable_manual_approval       = true
}
