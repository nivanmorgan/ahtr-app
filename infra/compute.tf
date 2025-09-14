resource "aws_ecs_cluster" "ahtr" { 
  name = coalesce(var.cluster_name, "${local.name_prefix}-cluster") 
  }

data "aws_iam_policy_document" "ecs_task_execution_role" {
  statement { 
    actions = ["sts:AssumeRole"] 
    principals { 
      type = "Service" 
      identifiers = ["ecs-tasks.amazonaws.com"] 
      } 
    }
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name               = "${local.name_prefix}-ecs-task-exec"
  assume_role_policy  = data.aws_iam_policy_document.ecs_task_execution_role.json
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "ecs_task_role" {
  name               = "${local.name_prefix}-ecs-task-role"
  assume_role_policy  = data.aws_iam_policy_document.ecs_task_execution_role.json
}

data "aws_iam_policy_document" "ecs_task_s3_read" {
  statement { 
    actions = ["s3:GetObject"] 
    resources = ["${aws_s3_bucket.images.arn}/*"] 
    }
  statement { 
    actions = ["s3:ListBucket","s3:GetBucketLocation"] 
    resources = [aws_s3_bucket.images.arn] 
    }
}
resource "aws_iam_policy" "ecs_task_s3_read" { 
  name = "${local.name_prefix}-ecs-task-s3-read" 
  policy = data.aws_iam_policy_document.ecs_task_s3_read.json 
  }
resource "aws_iam_role_policy_attachment" "ecs_task_s3_read_attach" { 
  role = aws_iam_role.ecs_task_role.name 
  policy_arn = aws_iam_policy.ecs_task_s3_read.arn 
  }

resource "aws_security_group" "ecs_sg" {
  name        = "${local.name_prefix}-ecs-sg"
  description = "Allow ALB to reach ECS"
  vpc_id      = local.vpc_id
  ingress { 
    from_port = 8000 
    to_port = 8000 
    protocol = "tcp" 
    security_groups = [aws_security_group.alb_sg.id] 
    }
  egress  { 
    from_port = 0 
    to_port = 0 
    protocol = "-1" 
    cidr_blocks = ["0.0.0.0/0"] 
    }
}

resource "aws_ecs_task_definition" "ahtr" {
  family                   = "${local.name_prefix}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "ahtr"
      image     = var.container_image
      essential = true
      portMappings = [{ containerPort = 8000, protocol = "tcp" }]
      environment = [
        { name = "S3_BUCKET_NAME", value = var.images_bucket_name },
        { name = "DB_HOST", value = aws_db_instance.ahtr_postgres.address },
        { name = "DB_NAME", value = var.db_name },
        { name = "DB_USER", value = var.db_user }
      ]
      secrets = [ { name = "DB_PASSWORD", valueFrom = aws_secretsmanager_secret.db_password.arn } ]
    }
  ])
}

resource "aws_ecs_service" "ahtr" {
  name            = "${local.name_prefix}-service"
  cluster         = aws_ecs_cluster.ahtr.id
  task_definition = aws_ecs_task_definition.ahtr.arn
  desired_count   = 1
  launch_type     = "FARGATE"
  network_configuration { 
    subnets = local.subnet_ids 
    security_groups = [aws_security_group.ecs_sg.id] 
    assign_public_ip = true 
    }
  load_balancer { 
    target_group_arn = aws_lb_target_group.app_tg.arn 
    container_name = "ahtr" 
    container_port = 8000 
    }
}
