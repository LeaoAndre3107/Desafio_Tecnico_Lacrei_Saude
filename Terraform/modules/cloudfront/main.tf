# Politicas gerenciadas pela AWS - referenciadas, nao criadas.
data "aws_cloudfront_cache_policy" "caching_disabled" {
  name = "Managed-CachingDisabled" # API dinamica de health-check: nunca cachear
}

data "aws_cloudfront_origin_request_policy" "all_viewer" {
  name = "Managed-AllViewer" # repassa headers/query/cookies ao ALB sem filtrar
}

resource "aws_wafv2_web_acl" "cloudfront" {
  name  = "${var.project_name}-cloudfront-waf"
  scope = "CLOUDFRONT"

  default_action {
    allow {}
  }

  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 0

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-common-rules"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.project_name}-cloudfront-waf"
    sampled_requests_enabled   = true
  }

  tags = var.tags
}

# CloudFront na frente do ALB para atender o requisito de HTTPS/TLS obrigatorio.
# Motivo da escolha: o ACM so emite certificado para dominio que voce controla,
# e o DNS do ALB (*.elb.amazonaws.com) nao e nosso. O dominio padrao do
# CloudFront (*.cloudfront.net) ja vem com certificado TLS valido da AWS,
# resolvendo HTTPS sem exigir a compra de um dominio proprio.
resource "aws_cloudfront_distribution" "this" {
  enabled         = true
  is_ipv6_enabled = true
  comment         = "${var.project_name} - HTTPS na frente do ALB"
  web_acl_id      = aws_wafv2_web_acl.cloudfront.arn

  # PriceClass_100 = so as edge locations mais baratas (America do Norte/Europa).
  # Decisao de custo consciente para ambiente de portfolio.
  price_class = "PriceClass_100"

  origin {
    domain_name = var.alb_dns_name
    origin_id   = "alb-origin"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }

    # Header secreto compartilhado: o ALB so aceita requisicoes que o
    # carreguem, impedindo que alguem contorne o HTTPS batendo direto no
    # DNS publico do ALB via HTTP.
    custom_header {
      name  = "X-Origin-Verify"
      value = var.origin_verify_secret
    }
  }

  default_cache_behavior {
    target_origin_id       = "alb-origin"
    viewer_protocol_policy = "redirect-to-https" # HTTP publico e redirecionado para HTTPS
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true

    cache_policy_id          = data.aws_cloudfront_cache_policy.caching_disabled.id
    origin_request_policy_id = data.aws_cloudfront_origin_request_policy.all_viewer.id
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
    minimum_protocol_version       = "TLSv1.2_2021"
  }

  tags = var.tags
}
