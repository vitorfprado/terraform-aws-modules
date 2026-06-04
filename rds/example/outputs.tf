output "db_instance_endpoint" {
  description = "Endpoint de conexão do banco (host:porta)."
  value       = module.rds.db_instance_endpoint
}

output "db_instance_address" {
  description = "Hostname do banco."
  value       = module.rds.db_instance_address
}

output "master_user_secret_arn" {
  description = "ARN do secret no Secrets Manager com a senha do usuário master."
  value       = module.rds.master_user_secret_arn
}

output "security_group_id" {
  description = "ID do security group do banco."
  value       = module.rds.security_group_id
}
