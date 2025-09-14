locals {
  environment  = element(split("/", path_relative_to_include()), 0)
  aws_region   = "us-west-2"
  state_bucket = "ahtr-terragrunt-state-${local.environment}"
  lock_table   = "ahtr-terragrunt-locks-${local.environment}"
}

remote_state {
  backend = "s3"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite"
  }
  config = {
    bucket         = local.state_bucket
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = local.aws_region
    encrypt        = true
    dynamodb_table = local.lock_table
  }
}

generate "provider" {
  path      = "provider_override.tf"
  if_exists = "overwrite"
  contents  = <<EOF
provider "aws" {
  region = "${local.aws_region}"
}
EOF
}

inputs = {}
