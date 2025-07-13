resource "aws_db_instance" "ahtr_postgres" {
  identifier         = "ahtr-db"
  engine             = "postgres"
  instance_class     = "db.t3.micro"
  allocated_storage  = 20
  name               = var.db_name
  username           = var.db_user
  password           = var.db_password
  publicly_accessible = true
  skip_final_snapshot = true

  vpc_security_group_ids = [aws_security_group.db_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.ahtr_subnet_group.name
}

resource "aws_security_group" "db_sg" {
  name        = "ahtr-db-sg"
  description = "Allow Postgres access"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 5432
    to_port     = 5432
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

resource "aws_db_subnet_group" "ahtr_subnet_group" {
  name       = "ahtr-db-subnets"
  subnet_ids = var.private_subnets
}
