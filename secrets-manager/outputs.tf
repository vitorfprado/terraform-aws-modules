output "secret_arn" {
  description = "ARN do secret. Use em políticas IAM e no remoteRef do External Secrets."
  value       = aws_secretsmanager_secret.secret.arn
}

output "secret_id" {
  description = "ID do secret (igual ao ARN no Secrets Manager)."
  value       = aws_secretsmanager_secret.secret.id
}

output "secret_name" {
  description = "Nome do secret (a key usada no remoteRef do External Secrets)."
  value       = aws_secretsmanager_secret.secret.name
}

output "version_id" {
  description = "ID da versão atual do secret."
  value       = aws_secretsmanager_secret_version.secret.version_id
}

output "kms_key_arn" {
  description = "ARN da KMS key dedicada, quando criada pelo módulo."
  value       = try(aws_kms_key.secret[0].arn, null)
}
