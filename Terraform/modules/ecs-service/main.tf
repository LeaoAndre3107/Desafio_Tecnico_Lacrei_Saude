data "aws_region" "current" {}

# --- IAM: role de execução da task (puxar imagem do ECR, mandar logs) ---
resource "aws_iam_role" "execution" {
  name = "lacrei-desafio-${var.service_name}-exec-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "execution" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# --- Logs ---
resource "aws_cloudwatch_log_group" "this" {
  name              = "/ecs/lacrei-desafio-${var.service_name}"
  retention_in_days = 7

  tags = var.tags
}

# --- Security group da task: só aceita trafego do ALB, nunca da internet direto ---
resource "aws_security_group" "service" {
  name        = "lacrei-desafio-${var.service_name}-sg"
  description = "Trafego apenas do ALB para a task ${var.service_name}"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Trafego do ALB na porta do container"
    from_port       = var.container_port
    to_port         = var.container_port
    protocol        = "tcp"
    security_groups = [var.alb_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "lacrei-desafio-${var.service_name}-sg" })
}

# --- Target group + listener rule (roteamento por path) ---
resource "aws_lb_target_group" "this" {
  name        = "lacrei-${var.service_name}-tg"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip" # obrigatorio para Fargate

  health_check {
    path                = "${var.app_prefix}/status"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 15
    timeout             = 5
    matcher             = "200"
  }

  tags = var.tags
}

resource "aws_lb_listener_rule" "this" {
  listener_arn = var.alb_listener_arn
  priority     = var.listener_rule_priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }

  condition {
    path_pattern {
      values = [var.path_pattern]
    }
  }
}

# --- Task definition ---
resource "aws_ecs_task_definition" "this" {
  family                   = "lacrei-desafio-${var.service_name}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.execution.arn

  container_definitions = jsonencode([
    {
      name      = var.service_name
      image     = "${var.ecr_repository_url}:${var.image_tag}"
      essential = true
      environment = [
        {
          name  = "APP_PREFIX"
          value = var.app_prefix
        }
      ]
      portMappings = [
        {
          containerPort = var.container_port
          protocol      = "tcp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.this.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = var.service_name
        }
      }
    }
  ])

  tags = var.tags
}

# --- Service ---
resource "aws_ecs_service" "this" {
  name            = "lacrei-desafio-${var.service_name}"
  cluster         = var.cluster_id
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.service.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.this.arn
    container_name   = var.service_name
    container_port   = var.container_port
  }

  depends_on = [aws_lb_listener_rule.this]

  tags = var.tags
}
