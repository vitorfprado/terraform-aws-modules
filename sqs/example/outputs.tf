output "queue_url" {
  description = "URL da fila principal."
  value       = module.sqs.queue_url
}

output "queue_arn" {
  description = "ARN da fila principal."
  value       = module.sqs.queue_arn
}

output "dlq_arn" {
  description = "ARN da dead-letter queue."
  value       = module.sqs.dlq_arn
}
