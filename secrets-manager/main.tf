locals {
  create_kms_key_resource = var.create_kms_key && var.kms_key_arn == null
  kms_key_arn             = var.kms_key_arn != null ? var.kms_key_arn : (local.create_kms_key_resource ? aws_kms_key.secret[0].arn : null)

  # secret_key_value (mapa) tem precedência e vira JSON; senão usa a string crua.
  secret_value = var.secret_key_value != null ? jsonencode(var.secret_key_value) : var.secret_string
}

resource "aws_secretsmanager_secret" "secret" {
  name                    = var.name
  description             = coalesce(var.description, "Secret ${var.name}")
  recovery_window_in_days = var.recovery_window_in_days
  kms_key_id              = local.kms_key_arn

  tags = merge(var.tags, { Name = var.name })
}

resource "aws_secretsmanager_secret_version" "secret" {
  secret_id     = aws_secretsmanager_secret.secret.id
  secret_string = local.secret_value

  lifecycle {
    precondition {
      condition     = (var.secret_string == null) != (var.secret_key_value == null)
      error_message = "Informe exatamente um entre secret_string e secret_key_value."
    }
  }
}
