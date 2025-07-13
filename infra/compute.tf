# ECS cluster for deploying the application

resource "aws_ecs_cluster" "ahtr" {
  name = var.cluster_name
}

# IAM role for ECS tasks
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ahtr-ecs-task-exec"

  assume_role_policy = data.aws_iam_policy_document.ecs_task_execution_role.json
}

# IAM policy document allowing ECS tasks to assume the role

data "aws_iam_policy_document" "ecs_task_execution_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Task definition for running the container
resource "aws_ecs_task_definition" "ahtr" {
  family                   = "ahtr"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "ahtr"
      image     = var.container_image
      essential = true
      portMappings = [
        {
          containerPort = 8000
          protocol      = "tcp"
        }
      ]
    }
  ])
}

# Security group for the ECS service
resource "aws_security_group" "ecs_sg" {
  name        = "ahtr-ecs-sg"
  description = "Allow HTTP access"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ECS service
resource "aws_ecs_service" "ahtr" {
  name            = "ahtr-service"
  cluster         = aws_ecs_cluster.ahtr.id
  task_definition = aws_ecs_task_definition.ahtr.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [aws_security_group.ecs_sg.id]
    assign_public_ip = true
  }
}
