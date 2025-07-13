terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }

  backend "s3" {
    bucket = var.state_bucket
    key    = "terraform.tfstate"
    region = var.region
  }
}

provider "aws" {
  region = var.region
}
