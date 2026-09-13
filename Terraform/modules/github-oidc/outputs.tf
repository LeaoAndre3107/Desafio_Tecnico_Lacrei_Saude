output "role_arn" {
  description = "ARN da role que o workflow do GitHub Actions vai assumir"
  value       = aws_iam_role.github_actions.arn
}
