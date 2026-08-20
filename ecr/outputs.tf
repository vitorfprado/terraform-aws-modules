output "repository_urls" {
  description = "URL de cada repositório, indexada pelo nome curto. É o destino do docker push."
  value       = { for k, v in aws_ecr_repository.main : k => v.repository_url }
}

output "repository_arns" {
  description = "ARN de cada repositório, indexado pelo nome curto. Use em policies IAM que precisem escopar o acesso."
  value       = { for k, v in aws_ecr_repository.main : k => v.arn }
}

output "repository_names" {
  description = "Nome completo de cada repositório (já com o namespace), indexado pelo nome curto."
  value       = { for k, v in aws_ecr_repository.main : k => v.name }
}

output "registry_id" {
  description = "ID do registry (conta AWS) onde os repositórios vivem."
  value       = values(aws_ecr_repository.main)[0].registry_id
}

output "registry_url" {
  description = "URL base do registry, sem o repositório. É o alvo do docker login."
  value       = split("/", values(aws_ecr_repository.main)[0].repository_url)[0]
}

output "kms_key_arn" {
  description = "ARN da KMS key criada pelo módulo, quando aplicável."
  value       = try(aws_kms_key.ecr[0].arn, null)
}

output "ssm_parameter_names" {
  description = "Nomes dos parâmetros publicados no Parameter Store, indexados pelo nome curto."
  value       = { for k, v in aws_ssm_parameter.repository_url : k => v.name }
}
