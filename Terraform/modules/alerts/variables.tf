variable "project_name" {
  type = string
}

variable "alert_email" {
  description = "E-mail que recebe as notificacoes do SNS quando um alarme dispara ou volta ao normal"
  type        = string
  sensitive   = true
}

variable "alb_arn_suffix" {
  description = "arn_suffix do ALB, usado como dimensao da metrica CloudWatch"
  type        = string
}

variable "services" {
  description = "Mapa nome-do-ambiente -> arn_suffix do target group correspondente"
  type = map(object({
    target_group_arn_suffix = string
  }))
}

variable "tags" {
  type    = map(string)
  default = {}
}
