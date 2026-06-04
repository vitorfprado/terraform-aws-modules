output "queue_url" {
  description = "URL da fila. Usada pelos producers/consumers para enviar e receber mensagens."
  value       = aws_sqs_queue.main.id
}

output "queue_arn" {
  description = "ARN da fila. Use em políticas IAM e como event source de Lambda."
  value       = aws_sqs_queue.main.arn
}

output "queue_name" {
  description = "Nome da fila (já com o sufixo .fifo, quando aplicável)."
  value       = aws_sqs_queue.main.name
}

output "dlq_url" {
  description = "URL da dead-letter queue, quando criada."
  value       = try(aws_sqs_queue.dlq[0].id, null)
}

output "dlq_arn" {
  description = "ARN da dead-letter queue, quando criada."
  value       = try(aws_sqs_queue.dlq[0].arn, null)
}

output "dlq_name" {
  description = "Nome da dead-letter queue, quando criada."
  value       = try(aws_sqs_queue.dlq[0].name, null)
}

output "kms_key_arn" {
  description = "ARN da KMS key usada na criptografia, quando uma key dedicada é criada pelo módulo."
  value       = try(aws_kms_key.sqs[0].arn, null)
}
