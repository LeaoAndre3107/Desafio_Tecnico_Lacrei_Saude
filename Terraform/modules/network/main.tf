module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.project_name}-vpc"
  cidr = var.vpc_cidr

  azs             = var.azs
  public_subnets  = var.public_subnet_cidrs
  private_subnets = var.private_subnet_cidrs

  # Decisão de custo consciente (mesma do bancox-eks): 1 NAT Gateway em vez de
  # 1 por AZ. Não é HA de produção, mas evita pagar por 2 NATs num projeto
  # de portfólio/desafio técnico.
  enable_nat_gateway = true
  single_nat_gateway = true

  enable_dns_hostnames = true
  enable_dns_support   = true

  public_subnet_tags = {
    "Tier" = "public"
  }
  private_subnet_tags = {
    "Tier" = "private"
  }

  tags = var.tags
}
