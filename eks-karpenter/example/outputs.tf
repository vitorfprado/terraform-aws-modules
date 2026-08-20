output "controller_role_arn" {
  description = "ARN da role do controller — anotação do service account do Karpenter."
  value       = module.karpenter.controller_role_arn
}

output "node_role_name" {
  description = "Nome da role dos nós — spec.role do EC2NodeClass."
  value       = module.karpenter.node_role_name
}

output "interruption_queue_name" {
  description = "Nome da fila de interrupção — settings.interruptionQueue do chart."
  value       = module.karpenter.interruption_queue_name
}

output "helm_values" {
  description = "Valores do chart derivados desta infraestrutura."
  value       = module.karpenter.helm_values
}

output "ssm_parameter_names" {
  description = "Parâmetros publicados no Parameter Store."
  value       = module.karpenter.ssm_parameter_names
}
