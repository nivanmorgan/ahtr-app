############################################
# Backend CI/CD: CodeBuild + CodePipeline
############################################

locals {
  be_pipeline_enabled = var.enable_backend_pipeline && var.repository_id != null && var.branch != null && var.code_connection_arn != null
}

# IAM role for CodeBuild
data "aws_iam_policy_document" "cb_be_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cb_be_role" {
  count              = local.be_pipeline_enabled ? 1 : 0
  name               = "${local.name_prefix}-cb-be-role"
  assume_role_policy = data.aws_iam_policy_document.cb_be_assume.json
}

data "aws_iam_policy_document" "cb_be_policy" {
  statement {
    sid     = "Logs"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["*"]
  }
  statement {
    sid     = "S3Artifacts"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:GetBucketLocation",
      "s3:ListBucket"
    ]
    resources = [
      aws_s3_bucket.artifacts.arn,
      "${aws_s3_bucket.artifacts.arn}/*"
    ]
  }
  # Split ECR access: auth token requires resource "*"
  statement {
    sid     = "ECRAuthToken"
    actions = [
      "ecr:GetAuthorizationToken"
    ]
    resources = ["*"]
  }
  statement {
    sid     = "ECRPush"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:CompleteLayerUpload",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart"
    ]
    resources = [aws_ecr_repository.ahtr.arn]
  }
}

resource "aws_iam_policy" "cb_be_policy" {
  count  = local.be_pipeline_enabled ? 1 : 0
  name   = "${local.name_prefix}-cb-be"
  policy = data.aws_iam_policy_document.cb_be_policy.json
}

resource "aws_iam_role_policy_attachment" "cb_be_attach" {
  count      = local.be_pipeline_enabled ? 1 : 0
  role       = aws_iam_role.cb_be_role[0].name
  policy_arn = aws_iam_policy.cb_be_policy[0].arn
}

resource "aws_codebuild_project" "backend" {
  count        = local.be_pipeline_enabled ? 1 : 0
  name         = "${local.name_prefix}-be-build"
  service_role = aws_iam_role.cb_be_role[0].arn

  artifacts { type = "CODEPIPELINE" }
  source    { type = "CODEPIPELINE" }

  environment {
    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = "aws/codebuild/standard:7.0"
    type            = "LINUX_CONTAINER"
    privileged_mode = true

    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = var.region
    }
    environment_variable {
      name  = "ECR_REPO_URI"
      value = aws_ecr_repository.ahtr.repository_url
    }
    environment_variable {
      name  = "CONTAINER_NAME"
      value = "ahtr"
    }
  }
}

# IAM role for CodePipeline
data "aws_iam_policy_document" "cp_be_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["codepipeline.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cp_be_role" {
  count              = local.be_pipeline_enabled ? 1 : 0
  name               = "${local.name_prefix}-cp-be-role"
  assume_role_policy = data.aws_iam_policy_document.cp_be_assume.json
}

data "aws_iam_policy_document" "cp_be_policy" {
  statement {
    sid     = "S3Artifacts"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:GetBucketLocation",
      "s3:ListBucket"
    ]
    resources = [
      aws_s3_bucket.artifacts.arn,
      "${aws_s3_bucket.artifacts.arn}/*"
    ]
  }
  statement {
    sid     = "CodeBuild"
    actions = [
      "codebuild:BatchGetBuilds",
      "codebuild:StartBuild"
    ]
    resources = [aws_codebuild_project.backend[0].arn]
  }
  statement {
    sid     = "CodeStarConnection"
    actions = ["codestar-connections:UseConnection"]
    resources = [var.code_connection_arn]
  }
  statement {
    sid     = "ECSDeploy"
    actions = [
      "ecs:DescribeClusters",
      "ecs:DescribeServices",
      "ecs:DescribeTaskDefinition",
      "ecs:DescribeTaskSets",
      "ecs:ListTaskDefinitions",
      "ecs:RegisterTaskDefinition",
      "ecs:UpdateService"
    ]
    resources = ["*"]
  }
  statement {
    sid     = "PassRolesForTaskDefinitions"
    actions = ["iam:PassRole"]
    resources = [
      aws_iam_role.ecs_task_execution_role.arn,
      aws_iam_role.ecs_task_role.arn
    ]
  }
  # Fallback: allow PassRole with condition restricted to ECS tasks
  statement {
    sid     = "PassRoleEcsTasksConditional"
    actions = ["iam:PassRole"]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_policy" "cp_be_policy" {
  count  = local.be_pipeline_enabled ? 1 : 0
  name   = "${local.name_prefix}-cp-be"
  policy = data.aws_iam_policy_document.cp_be_policy.json
}

resource "aws_iam_role_policy_attachment" "cp_be_attach" {
  count      = local.be_pipeline_enabled ? 1 : 0
  role       = aws_iam_role.cp_be_role[0].name
  policy_arn = aws_iam_policy.cp_be_policy[0].arn
}

resource "aws_codepipeline" "backend" {
  count    = local.be_pipeline_enabled ? 1 : 0
  name     = "${local.name_prefix}-be-pipeline"
  role_arn = aws_iam_role.cp_be_role[0].arn

  artifact_store {
    type     = "S3"
    location = aws_s3_bucket.artifacts.bucket
  }

  stage {
    name = "Source"
    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["SourceArtifact"]
      configuration = {
        ConnectionArn    = var.code_connection_arn
        FullRepositoryId  = var.repository_id
        BranchName        = var.branch
        DetectChanges     = "true"
      }
    }
  }

  stage {
    name = "Build"
    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["SourceArtifact"]
      output_artifacts = ["BuildArtifact"]
      configuration = {
        ProjectName = aws_codebuild_project.backend[0].name
      }
    }
  }

  # Optional manual approval before deploy (e.g., for prod)
  dynamic "stage" {
    for_each = var.enable_manual_approval ? [1] : []
    content {
      name = "Approve"
      action {
        name             = "ManualApproval"
        category         = "Approval"
        owner            = "AWS"
        provider         = "Manual"
        version          = "1"
        input_artifacts  = []
        output_artifacts = []
        configuration = {
          CustomData = "Approve production deploy"
        }
      }
    }
  }

  stage {
    name = "Deploy"
    action {
      name            = "DeployToECS"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "ECS"
      version         = "1"
      input_artifacts = ["BuildArtifact"]
      configuration = {
        ClusterName = aws_ecs_cluster.ahtr.name
        ServiceName = aws_ecs_service.ahtr.name
        FileName    = "imagedefinitions.json"
      }
    }
  }
}

output "backend_pipeline_name" {
  value       = local.be_pipeline_enabled ? aws_codepipeline.backend[0].name : null
  description = "Backend CodePipeline name (if enabled)"
}

output "backend_codebuild_project" {
  value       = local.be_pipeline_enabled ? aws_codebuild_project.backend[0].name : null
  description = "Backend CodeBuild project (if enabled)"
}
