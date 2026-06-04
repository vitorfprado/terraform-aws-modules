output "analytics_role_arn" {
  description = "ARN da IRSA role do analytics-service."
  value       = module.irsa_analytics.role_arn
}

output "analytics_ssm_parameter_name" {
  description = "Parâmetro SSM com o ARN da role do analytics-service."
  value       = module.irsa_analytics.ssm_parameter_name
}

output "readonly_role_arn" {
  description = "ARN da IRSA role somente-leitura."
  value       = module.irsa_readonly.role_arn
}
