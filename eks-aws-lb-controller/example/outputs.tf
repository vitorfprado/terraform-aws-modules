output "role_arn" {
  description = "ARN da role — anotação do service account do controller."
  value       = module.lb_controller.role_arn
}

output "helm_values" {
  description = "Valores do chart derivados desta infraestrutura."
  value       = module.lb_controller.helm_values
}

output "ssm_parameter_names" {
  description = "Parâmetros publicados no Parameter Store."
  value       = module.lb_controller.ssm_parameter_names
}
