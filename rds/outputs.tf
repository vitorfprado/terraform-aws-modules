output "db_instance_id" {
  description = "Identificador da instância RDS."
  value       = aws_db_instance.main.identifier
}

output "db_instance_arn" {
  description = "ARN da instância RDS."
  value       = aws_db_instance.main.arn
}

output "db_instance_endpoint" {
  description = "Endpoint de conexão no formato host:porta."
  value       = aws_db_instance.main.endpoint
}

output "db_instance_address" {
  description = "Hostname (DNS) da instância, sem a porta."
  value       = aws_db_instance.main.address
}

output "db_instance_port" {
  description = "Porta de conexão do banco."
  value       = aws_db_instance.main.port
}

output "db_instance_name" {
  description = "Nome do banco de dados inicial, quando criado."
  value       = aws_db_instance.main.db_name
}

output "db_instance_username" {
  description = "Usuário master do banco."
  value       = aws_db_instance.main.username
}

output "master_user_secret_arn" {
  description = "ARN do secret no Secrets Manager com a senha do usuário master (quando manage_master_user_password = true)."
  value       = try(aws_db_instance.main.master_user_secret[0].secret_arn, null)
}

output "db_subnet_group_name" {
  description = "Nome do subnet group do RDS."
  value       = aws_db_subnet_group.rds.name
}

output "security_group_id" {
  description = "ID do security group criado pelo módulo, quando habilitado."
  value       = try(aws_security_group.rds[0].id, null)
}

output "kms_key_arn" {
  description = "ARN da KMS key usada para criptografar o armazenamento."
  value       = local.kms_key_arn
}

output "monitoring_role_arn" {
  description = "ARN da IAM role do Enhanced Monitoring, quando habilitado."
  value       = local.monitoring_role_arn
}

output "parameter_group_name" {
  description = "Nome do parameter group em uso pela instância."
  value       = local.parameter_group_name
}
