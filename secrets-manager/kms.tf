resource "aws_kms_key" "secret" {
  count = local.create_kms_key_resource ? 1 : 0

  description             = "Criptografia do secret ${var.name}"
  enable_key_rotation     = true
  deletion_window_in_days = var.kms_key_deletion_window_in_days
  tags                    = var.tags
}

resource "aws_kms_alias" "secret" {
  count = local.create_kms_key_resource ? 1 : 0

  name          = "alias/secretsmanager/${var.name}"
  target_key_id = aws_kms_key.secret[0].key_id
}
