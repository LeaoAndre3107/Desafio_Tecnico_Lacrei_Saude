variable "project_name" {
  description = "Prefixo usado no nome dos recursos"
  type        = string
}

variable "vpc_id" {
  description = "ID da VPC (output do módulo network)"
  type        = string
}

variable "public_subnet_ids" {
  description = "Subnets públicas onde o ALB vive (output do módulo network)"
  type        = list(string)
}

variable "ecr_repository_names" {
  description = "Nomes dos repositórios ECR a criar, um por serviço"
  type        = list(string)
  default     = ["devops-app", "devsecops-app"]
}

variable "tags" {
  description = "Tags comuns"
  type        = map(string)
  default     = {}
}
