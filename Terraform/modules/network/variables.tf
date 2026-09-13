variable "project_name" {
  description = "Prefixo usado no nome dos recursos"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block da VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "azs" {
  description = "Availability Zones usadas (2, mesmo padrão do bancox-eks)"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "CIDRs das subnets públicas (uma por AZ) - onde o ALB fica"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDRs das subnets privadas (uma por AZ) - onde as tasks ECS rodam"
  type        = list(string)
}

variable "tags" {
  description = "Tags comuns aplicadas a todos os recursos de rede"
  type        = map(string)
  default     = {}
}
