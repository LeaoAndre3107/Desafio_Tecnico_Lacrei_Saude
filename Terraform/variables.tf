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

variable "devops_image_tag" {
  description = "Tag da imagem devops-app a deployar (o pipeline sobrescreve isso com o SHA do commit)"
  type        = string
  default     = "v2"
}
