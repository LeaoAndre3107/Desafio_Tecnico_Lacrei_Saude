variable "project_name" {
  description = "Prefixo usado no nome dos recursos"
  type        = string
  default     = "lacrei-desafio"
}

variable "region" {
  description = "Região AWS"
  type        = string
  default     = "us-east-1"
}

variable "azs" {
  description = "Availability Zones usadas (2)"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "devops_staging_image_tag" {
  description = "Tag da imagem devops-app em staging. SEM DEFAULT DE PROPOSITO: sempre passar explicitamente (via -var ou TF_VAR_), nunca deixar um valor parado servir de default silencioso - ja causamos um rollback acidental assim nesta sessao."
  type        = string
}

variable "devops_production_image_tag" {
  description = "Tag da imagem devops-app em producao. Promovida a partir de uma tag ja validada em staging, nunca de um novo build direto."
  type        = string
}
