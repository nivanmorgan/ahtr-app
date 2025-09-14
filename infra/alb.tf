resource "aws_security_group" "alb_sg" {
  name        = "${local.name_prefix}-alb-sg"
  description = "Allow HTTP"
  vpc_id      = local.vpc_id

  ingress { 
    from_port = 80 
    to_port = 80 
    protocol = "tcp" 
    cidr_blocks = ["0.0.0.0/0"] 
    }
  egress  { 
    from_port = 0 
    to_port = 0 
    protocol = "-1" 
    cidr_blocks = ["0.0.0.0/0"] 
    }
}

resource "aws_lb" "app_alb" {
  name               = "${local.name_prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = local.subnet_ids
}

resource "aws_lb_target_group" "app_tg" {
  name        = "${local.name_prefix}-tg"
  port        = 8000
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = local.vpc_id
  health_check { 
    path = "/health" 
    matcher = "200-399" 
    interval = 30 
    timeout = 5 
    }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app_alb.arn
  port = 80
  protocol = "HTTP"
  default_action { 
    type = "forward" 
    target_group_arn = aws_lb_target_group.app_tg.arn 
    }
}

