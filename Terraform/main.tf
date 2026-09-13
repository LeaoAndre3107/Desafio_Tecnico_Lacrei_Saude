provider "aws" {
  region = var.region
}

data "aws_caller_identity" "current" {}

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

  github_repo             = "LeaoAndre3107/Desafio_Tecnico_Lacrei_Saude"
  github_branch           = "main"
  account_id              = data.aws_caller_identity.current.account_id
  terraform_state_bucket  = "lacrei-desafio-terraform-state"

  tags = {
    Project = var.project_name
    Managed = "terraform"
  }
}

module "ecs_service_devops" {
  source = "./modules/ecs-service"

  service_name = "devops-app"

  vpc_id                 = module.network.vpc_id
  private_subnet_ids     = module.network.private_subnet_ids
  cluster_id             = module.ecs_cluster.cluster_id
  alb_security_group_id  = module.ecs_cluster.alb_security_group_id
  alb_listener_arn       = module.ecs_cluster.alb_listener_arn
  listener_rule_priority = 10
  path_pattern            = "/devops/*"
  app_prefix              = "/devops"

  ecr_repository_url = module.ecs_cluster.ecr_repository_urls["devops-app"]
  image_tag           = var.devops_image_tag

  tags = {
    Project = var.project_name
    Managed = "terraform"
  }
}
