output "replication_group_id" {
  description = "ID do replication group."
  value       = aws_elasticache_replication_group.main.id
}

output "replication_group_arn" {
  description = "ARN do replication group."
  value       = aws_elasticache_replication_group.main.arn
}

output "primary_endpoint_address" {
  description = "Endpoint de escrita (primário). Disponível no modo não-cluster."
  value       = aws_elasticache_replication_group.main.primary_endpoint_address
}

output "reader_endpoint_address" {
  description = "Endpoint de leitura (réplicas). Disponível no modo não-cluster."
  value       = aws_elasticache_replication_group.main.reader_endpoint_address
}

output "configuration_endpoint_address" {
  description = "Endpoint de configuração. Disponível no modo cluster (sharding)."
  value       = aws_elasticache_replication_group.main.configuration_endpoint_address
}

output "port" {
  description = "Porta de conexão do cache."
  value       = aws_elasticache_replication_group.main.port
}

output "member_clusters" {
  description = "Identificadores dos nós que compõem o replication group."
  value       = aws_elasticache_replication_group.main.member_clusters
}

output "security_group_id" {
  description = "ID do security group criado pelo módulo, quando habilitado."
  value       = try(aws_security_group.elasticache[0].id, null)
}

output "subnet_group_name" {
  description = "Nome do subnet group do cache."
  value       = aws_elasticache_subnet_group.main.name
}

output "kms_key_arn" {
  description = "ARN da KMS key usada na criptografia em repouso, quando uma key dedicada é criada pelo módulo."
  value       = try(aws_kms_key.elasticache[0].arn, null)
}
