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

output "devops_staging_url" {
  description = "URL publica de staging (HTTPS via CloudFront)"
  value       = "https://${module.cloudfront.domain_name}/devops/staging/status"
}

output "devops_production_url" {
  description = "URL publica de producao (HTTPS via CloudFront)"
  value       = "https://${module.cloudfront.domain_name}/devops/production/status"
}

output "cloudfront_domain_name" {
  value = module.cloudfront.domain_name
}

output "devops_staging_image_tag" {
  description = "Tag atualmente aplicada em staging - o pipeline le isso antes de aplicar mudanca em produção"
  value       = module.ecs_service_devops_staging.image_tag
}

output "devops_production_image_tag" {
  description = "Tag atualmente aplicada em producao"
  value       = module.ecs_service_devops_production.image_tag
}

output "github_actions_role_arn" {
  value = module.github_oidc.role_arn
}
