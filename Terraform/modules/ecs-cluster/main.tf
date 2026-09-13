resource "aws_ecs_cluster" "this" {
  name = "${var.project_name}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = var.tags
}

# Security group do ALB: só ele fica exposto na internet.
# As tasks ECS (no módulo ecs-service) só aceitam tráfego vindo deste SG,
# nunca 0.0.0.0/0 direto na porta do container.
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "Trafego publico HTTP para o ALB"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP publico"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.project_name}-alb-sg" })
}

resource "aws_lb" "this" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids

  tags = var.tags
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  # Default action deliberada: 404 fixo em vez de apontar pra um target group.
  # Path nao mapeado por uma listener rule cai aqui - sinal limpo de erro de
  # rota, em vez de tráfego indo parar num serviço errado.
  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "404 - rota nao encontrada"
      status_code  = "404"
    }
  }
}

resource "aws_ecr_repository" "this" {
  for_each = toset(var.ecr_repository_names)

  name                 = each.value
  image_tag_mutability = "IMMUTABLE"

  # force_delete: aceitável aqui porque é ambiente de portfólio/teste, onde
  # o destroy/apply se repete. NAO faria isso num ECR de produção real -
  # lá, um destroy acidental apagando imagens em uso seria grave.
  force_delete = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = var.tags
}
