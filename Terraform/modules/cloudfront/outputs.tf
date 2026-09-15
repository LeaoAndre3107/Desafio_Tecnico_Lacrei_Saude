output "domain_name" {
  description = "Dominio publico HTTPS da distribuicao"
  value       = aws_cloudfront_distribution.this.domain_name
}

output "distribution_id" {
  value = aws_cloudfront_distribution.this.id
}
