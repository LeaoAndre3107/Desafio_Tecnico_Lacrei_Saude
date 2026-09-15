variable "service_name" {
  description = "Nome curto do serviço (ex: devops-app, devsecops-app)"
  type        = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "cluster_id" {
  type = string
}

variable "alb_security_group_id" {
  type = string
}

variable "alb_listener_arn" {
  type = string
}

variable "listener_rule_priority" {
  description = "Prioridade da regra no listener - precisa ser unica por servico no mesmo listener"
  type        = number
}

variable "path_pattern" {
  description = "Path pattern do roteamento no ALB, ex: /devops/*"
  type        = string
}

variable "app_prefix" {
  description = "Prefixo que o app escuta internamente (ex: /devops), repassado como env var APP_PREFIX ao container. Precisa bater com path_pattern sem o /* final."
  type        = string
  default     = ""
}

variable "origin_verify_secret" {
  description = "Header secreto que o CloudFront envia. O listener so encaminha requisicoes que o carreguem."
  type        = string
  sensitive   = true
}

variable "ecr_repository_url" {
  type = string
}

variable "image_tag" {
  type = string
}

variable "container_port" {
  type    = number
  default = 3000
}

variable "task_cpu" {
  description = "CPU da task Fargate (unidades: 256 = 0.25 vCPU)"
  type        = string
  default     = "256"
}

variable "task_memory" {
  description = "Memoria da task Fargate em MB"
  type        = string
  default     = "512"
}

variable "desired_count" {
  type    = number
  default = 1
}

variable "tags" {
  type    = map(string)
  default = {}
}
