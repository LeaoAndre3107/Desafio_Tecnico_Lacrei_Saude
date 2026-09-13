output "vpc_id" {
  value = module.network.vpc_id
}

output "public_subnet_ids" {
  value = module.network.public_subnet_ids
}

output "private_subnet_ids" {
  value = module.network.private_subnet_ids
}

output "alb_dns_name" {
  value = module.ecs_cluster.alb_dns_name
}

output "ecr_repository_urls" {
  value = module.ecs_cluster.ecr_repository_urls
}

output "devops_app_url" {
  value = "http://${module.ecs_cluster.alb_dns_name}/devops/status"
}

output "github_actions_role_arn" {
  value = module.github_oidc.role_arn
}
