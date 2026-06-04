output "rds_secret_arn" {
  description = "ARN do secret de credenciais do RDS."
  value       = module.rds_secret.secret_arn
}

output "rds_secret_name" {
  description = "Nome do secret (key do remoteRef no External Secrets)."
  value       = module.rds_secret.secret_name
}

output "api_key_secret_arn" {
  description = "ARN do secret de API key."
  value       = module.api_key_secret.secret_arn
}
