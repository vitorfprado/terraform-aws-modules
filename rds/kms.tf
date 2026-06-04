resource "aws_kms_key" "rds" {
  count = local.create_kms_key_resource ? 1 : 0

  description             = "Criptografia de armazenamento do RDS ${var.name}"
  enable_key_rotation     = true
  deletion_window_in_days = var.kms_key_deletion_window_in_days
  tags                    = var.tags
}

resource "aws_kms_alias" "rds" {
  count = local.create_kms_key_resource ? 1 : 0

  name          = "alias/rds/${var.name}"
  target_key_id = aws_kms_key.rds[0].key_id
}
