resource "aws_sns_topic" "alerts" {
  name              = "${var.project_name}-alerts"
  kms_master_key_id = "alias/aws/sns"
  tags              = var.tags
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# Um alarme por ambiente (staging, producao) - dispara quando pelo menos 1
# target do ALB fica unhealthy por 2 periodos seguidos (2 minutos), e avisa
# de novo quando volta ao normal (ok_actions). UnHealthyHostCount e a metrica
# mais direta de "o servico caiu do ponto de vista de quem acessa" - mais
# valiosa aqui que CPU/memoria isoladas.
resource "aws_cloudwatch_metric_alarm" "unhealthy_targets" {
  for_each = var.services

  alarm_name          = "${var.project_name}-${each.key}-unhealthy-targets"
  alarm_description   = "Pelo menos 1 target unhealthy em ${each.key} por 2 minutos seguidos"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Maximum"
  threshold           = 1

  # Ausência de métrica é tratada como violação: um target sem datapoint
  # não deve esconder uma possível indisponibilidade do serviço.
  treat_missing_data = "breaching"


  dimensions = {
    LoadBalancer = var.alb_arn_suffix
    TargetGroup  = each.value.target_group_arn_suffix
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  tags = var.tags
}
