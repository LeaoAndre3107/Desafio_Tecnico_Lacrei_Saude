provider "aws" {
  region = var.region
}

data "aws_caller_identity" "current" {}

# Segredo compartilhado entre CloudFront e ALB, gerado automaticamente.
# Fica no state (que ja e privado e criptografado no S3), nunca no codigo.
resource "random_password" "origin_verify" {
  length  = 40
  special = false
}

module "network" {
  source = "./modules/network"

  project_name = var.project_name

  vpc_cidr             = "10.20.0.0/16"
  azs                  = var.azs
  public_subnet_cidrs  = ["10.20.1.0/24", "10.20.2.0/24"]
  private_subnet_cidrs = ["10.20.11.0/24", "10.20.12.0/24"]

  tags = {
    Project = var.project_name
    Managed = "terraform"
  }
}

module "ecs_cluster" {
  source = "./modules/ecs-cluster"

  project_name      = var.project_name
  vpc_id            = module.network.vpc_id
  public_subnet_ids = module.network.public_subnet_ids

  tags = {
    Project = var.project_name
    Managed = "terraform"
  }
}

module "github_oidc" {
  source = "./modules/github-oidc"

  github_owner      = "LeaoAndre3107"
  github_owner_id   = "119906272"
  github_repo_name  = "Desafio_Tecnico_Lacrei_Saude"
  github_repo_id    = "1367803676"
  github_branch           = "main"
  account_id              = data.aws_caller_identity.current.account_id
  terraform_state_bucket  = "lacrei-desafio-terraform-state"

  tags = {
    Project = var.project_name
    Managed = "terraform"
  }
}

module "ecs_service_devops_staging" {
  source = "./modules/ecs-service"

  service_name = "devops-app-staging"

  vpc_id                 = module.network.vpc_id
  private_subnet_ids     = module.network.private_subnet_ids
  cluster_id             = module.ecs_cluster.cluster_id
  alb_security_group_id  = module.ecs_cluster.alb_security_group_id
  alb_listener_arn       = module.ecs_cluster.alb_listener_arn
  listener_rule_priority = 10
  path_pattern            = "/devops/staging/*"
  app_prefix              = "/devops/staging"
  origin_verify_secret    = random_password.origin_verify.result

  ecr_repository_url = module.ecs_cluster.ecr_repository_urls["devops-app"]
  image_tag           = var.devops_staging_image_tag

  tags = {
    Project     = var.project_name
    Managed     = "terraform"
    Environment = "staging"
  }
}

module "ecs_service_devops_production" {
  source = "./modules/ecs-service"

  service_name = "devops-app-production"

  vpc_id                 = module.network.vpc_id
  private_subnet_ids     = module.network.private_subnet_ids
  cluster_id             = module.ecs_cluster.cluster_id
  alb_security_group_id  = module.ecs_cluster.alb_security_group_id
  alb_listener_arn       = module.ecs_cluster.alb_listener_arn
  listener_rule_priority = 20
  path_pattern            = "/devops/production/*"
  app_prefix              = "/devops/production"
  origin_verify_secret    = random_password.origin_verify.result

  ecr_repository_url = module.ecs_cluster.ecr_repository_urls["devops-app"]
  image_tag           = var.devops_production_image_tag

  tags = {
    Project     = var.project_name
    Managed     = "terraform"
    Environment = "production"
  }
}

module "cloudfront" {
  source = "./modules/cloudfront"

  project_name         = var.project_name
  alb_dns_name         = module.ecs_cluster.alb_dns_name
  origin_verify_secret = random_password.origin_verify.result

  tags = {
    Project = var.project_name
    Managed = "terraform"
  }
}

module "alerts" {
  source = "./modules/alerts"

  project_name   = var.project_name
  alert_email    = var.alert_email
  alb_arn_suffix = module.ecs_cluster.alb_arn_suffix

  services = {
    staging = {
      target_group_arn_suffix = module.ecs_service_devops_staging.target_group_arn_suffix
    }
    production = {
      target_group_arn_suffix = module.ecs_service_devops_production.target_group_arn_suffix
    }
  }

  tags = {
    Project = var.project_name
    Managed = "terraform"
  }
}
