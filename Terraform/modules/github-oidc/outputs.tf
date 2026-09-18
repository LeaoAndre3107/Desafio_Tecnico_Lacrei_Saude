output "role_arn" {
  description = "ARN da role que o workflow do GitHub Actions vai assumir"
  value       = aws_iam_role.github_actions.arn
}

output "app_deploy_role_arn" {
  description = "ARN da role restrita ao deploy da aplicação"
  value       = aws_iam_role.app_deploy.arn
}
