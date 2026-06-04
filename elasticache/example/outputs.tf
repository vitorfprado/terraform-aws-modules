output "primary_endpoint_address" {
  description = "Endpoint de escrita do Redis."
  value       = module.elasticache.primary_endpoint_address
}

output "reader_endpoint_address" {
  description = "Endpoint de leitura do Redis."
  value       = module.elasticache.reader_endpoint_address
}

output "port" {
  description = "Porta de conexão."
  value       = module.elasticache.port
}

output "security_group_id" {
  description = "ID do security group do cache."
  value       = module.elasticache.security_group_id
}
