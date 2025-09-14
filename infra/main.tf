terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
  default_tags { 
    tags = { 
      Project = var.project, 
      Environment = var.environment 
      } 
      }
}

# Default VPC/subnets if none provided
data "aws_vpc" "default" { default = true }
data "aws_subnets" "default" {
  filter { 
    name = "vpc-id" 
    values = [data.aws_vpc.default.id] 
    }
}

locals {
  vpc_id      = var.vpc_id != null ? var.vpc_id : data.aws_vpc.default.id
  subnet_ids  = var.subnet_ids != null ? var.subnet_ids : data.aws_subnets.default.ids
  name_prefix = "${var.project}-${var.environment}"
}
