resource "aws_secretsmanager_secret" "db_password" {
  name        = "${local.name_prefix}-db-password"
  description = "Database password for ${local.name_prefix}"
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = var.db_password
}

# Allow ECS execution role to fetch the DB password secret
data "aws_iam_policy_document" "ecs_exec_secrets" {
  statement {
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [aws_secretsmanager_secret.db_password.arn]
  }
}

resource "aws_iam_policy" "ecs_exec_secrets" {
  name   = "${local.name_prefix}-ecs-exec-secrets"
  policy = data.aws_iam_policy_document.ecs_exec_secrets.json
}

resource "aws_iam_role_policy_attachment" "ecs_exec_secrets_attach" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = aws_iam_policy.ecs_exec_secrets.arn
}

# Allow CodeBuild import role to fetch the DB password secret
data "aws_iam_policy_document" "cb_import_secrets" {
  statement {
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [aws_secretsmanager_secret.db_password.arn]
  }
}

resource "aws_iam_policy" "cb_import_secrets" {
  name   = "${local.name_prefix}-cb-import-secrets"
  policy = data.aws_iam_policy_document.cb_import_secrets.json
}

resource "aws_iam_role_policy_attachment" "cb_import_secrets_attach" {
  count      = var.enable_data_import_job ? 1 : 0
  role       = aws_iam_role.codebuild_import_role[0].name
  policy_arn = aws_iam_policy.cb_import_secrets.arn
}

