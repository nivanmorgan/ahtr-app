resource "aws_db_subnet_group" "ahtr_subnet_group" {
  name       = "${local.name_prefix}-db-subnets"
  subnet_ids = local.subnet_ids

  tags = {
    Name = "ahtr-db-subnets"
  }
}

resource "aws_db_instance" "ahtr_postgres" {
  identifier          = "${local.name_prefix}-db"
  engine              = "postgres"
  instance_class      = "db.t3.micro"
  allocated_storage   = 20
  db_name                = var.db_name
  username            = var.db_user
  password            = var.db_password
  publicly_accessible = true
  skip_final_snapshot = true

  vpc_security_group_ids = [aws_security_group.db_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.ahtr_subnet_group.name
}

resource "aws_security_group" "db_sg" {
  name        = "${local.name_prefix}-db-sg"
  description = "Allow Postgres access"
  vpc_id      = local.vpc_id

  ingress { 
    from_port = 5432 
    to_port = 5432 
    protocol = "tcp" 
    security_groups = [aws_security_group.ecs_sg.id] 
    }

  # Allow CodeBuild (data import) to access RDS when enabled
  dynamic "ingress" {
    for_each = var.enable_data_import_job ? [1] : []
    content {
      from_port       = 5432
      to_port         = 5432
      protocol        = "tcp"
      security_groups = [aws_security_group.codebuild_sg[0].id]
      description     = "CodeBuild import to RDS"
    }
  }

  # Optional: allow developer CIDRs for direct psql access in dev
  dynamic "ingress" {
    for_each = var.db_additional_cidrs
    content {
      from_port   = 5432
      to_port     = 5432
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
      description = "Dev access"
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
