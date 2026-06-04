output "table_name" {
  description = "Nome da tabela DynamoDB."
  value       = aws_dynamodb_table.main.name
}

output "table_id" {
  description = "ID da tabela (igual ao nome)."
  value       = aws_dynamodb_table.main.id
}

output "table_arn" {
  description = "ARN da tabela. Use em políticas IAM dos consumidores."
  value       = aws_dynamodb_table.main.arn
}

output "table_stream_arn" {
  description = "ARN do stream da tabela, quando habilitado. Use como event source de uma Lambda, por exemplo."
  value       = try(aws_dynamodb_table.main.stream_arn, null)
}

output "table_stream_label" {
  description = "Label do stream (timestamp), quando habilitado."
  value       = try(aws_dynamodb_table.main.stream_label, null)
}

output "kms_key_arn" {
  description = "ARN da KMS key usada na criptografia, quando uma key gerenciada pelo módulo ou informada é utilizada."
  value       = local.kms_key_arn
}
