############################################
# Data Import CodeBuild (runs importer in VPC)
############################################

variable "enable_data_import_job" {
  description = "Create CodeBuild project for data import"
  type        = bool
  default     = true
}

resource "aws_iam_role" "codebuild_import_role" {
  count              = var.enable_data_import_job ? 1 : 0
  name               = "${local.name_prefix}-cb-import-role"
  assume_role_policy = data.aws_iam_policy_document.codebuild_trust.json
}

data "aws_iam_policy_document" "codebuild_trust" {
  statement { 
    actions = ["sts:AssumeRole"] 
    principals { 
      type = "Service" 
      identifiers = ["codebuild.amazonaws.com"] 
      } 
    }
}

resource "aws_iam_role_policy_attachment" "codebuild_import_dev_access" {
  count      = var.enable_data_import_job ? 1 : 0
  role       = aws_iam_role.codebuild_import_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeBuildDeveloperAccess"
}

resource "aws_iam_role_policy_attachment" "codebuild_import_s3_read" {
  count      = var.enable_data_import_job ? 1 : 0
  role       = aws_iam_role.codebuild_import_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}

data "aws_iam_policy_document" "codebuild_import_vpc_logs" {
  statement {
    actions = [
      "ec2:CreateNetworkInterface",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DeleteNetworkInterface",
      "ec2:DescribeSubnets",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeVpcs"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "codebuild_import_vpc_logs" {
  count  = var.enable_data_import_job ? 1 : 0
  name   = "${local.name_prefix}-cb-import-vpc"
  policy = data.aws_iam_policy_document.codebuild_import_vpc_logs.json
}

resource "aws_iam_role_policy_attachment" "codebuild_import_vpc_logs_attach" {
  count      = var.enable_data_import_job ? 1 : 0
  role       = aws_iam_role.codebuild_import_role[0].name
  policy_arn = aws_iam_policy.codebuild_import_vpc_logs[0].arn
}

resource "aws_security_group" "codebuild_sg" {
  count       = var.enable_data_import_job ? 1 : 0
  name        = "${local.name_prefix}-cb-import-sg"
  description = "SG for CodeBuild data import to access RDS"
  vpc_id      = local.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_codebuild_project" "data_import" {
  count        = var.enable_data_import_job ? 1 : 0
  name         = "${local.name_prefix}-data-import"
  service_role = aws_iam_role.codebuild_import_role[0].arn

  artifacts { type = "NO_ARTIFACTS" }

  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/standard:7.0"
    type         = "LINUX_CONTAINER"
        environment_variable { 
          name = "AWS_DEFAULT_REGION" 
          value = var.region 
          }
    # Default CSV path for imports (can be overridden at build time)
    environment_variable {
      name  = "CSV_S3"
      value = "s3://${var.images_bucket_name}/imports/transcarta.csv"
    }
    environment_variable { 
      name = "DB_HOST"           
      value = aws_db_instance.ahtr_postgres.address 
      }
    environment_variable { 
      name = "DB_NAME"           
      value = var.db_name 
      }
    environment_variable { 
      name = "DB_USER"           
      value = var.db_user 
      }
    environment_variable {
      name  = "DB_PASSWORD"
      value = aws_secretsmanager_secret.db_password.arn
      type  = "SECRETS_MANAGER"
    }
  }

  source {
    type            = "GITHUB"
    # Use the same repository as the backend so buildspec can access scripts/import_csv.py and requirements.txt
    location        = "https://github.com/${var.repository_id}.git"
    git_clone_depth = 1
    buildspec       = file("${path.module}/buildspec-data-import.yml")
  }

  vpc_config {
    vpc_id             = local.vpc_id
    subnets            = local.subnet_ids
    security_group_ids = [aws_security_group.codebuild_sg[0].id]
  }
}

output "codebuild_data_import_name" {
  value       = var.enable_data_import_job ? aws_codebuild_project.data_import[0].name : null
  description = "CodeBuild project name for data import"
}
