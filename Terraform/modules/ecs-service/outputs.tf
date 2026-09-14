output "target_group_arn" {
  value = aws_lb_target_group.this.arn
}

output "service_name" {
  value = aws_ecs_service.this.name
}

output "task_definition_arn" {
  value = aws_ecs_task_definition.this.arn
}

output "image_tag" {
  description = "Tag de imagem atualmente aplicada - permite ao pipeline consultar o estado sem precisar rebuildar"
  value       = var.image_tag
}
