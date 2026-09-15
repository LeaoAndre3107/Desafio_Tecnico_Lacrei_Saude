variable "project_name" {
  description = "Prefixo usado no nome/comentario dos recursos"
  type        = string
}

variable "alb_dns_name" {
  description = "DNS name do ALB que serve de origem"
  type        = string
}

variable "origin_verify_secret" {
  description = "Valor do header secreto que o CloudFront envia ao ALB. O listener do ALB so aceita requisicoes que o carreguem, impedindo bypass do HTTPS via acesso direto ao ALB."
  type        = string
  sensitive   = true
}

variable "tags" {
  type    = map(string)
  default = {}
}
