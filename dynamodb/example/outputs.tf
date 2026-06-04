output "table_name" {
  description = "Nome da tabela criada."
  value       = module.dynamodb.table_name
}

output "table_arn" {
  description = "ARN da tabela (use em políticas IAM dos consumidores)."
  value       = module.dynamodb.table_arn
}
