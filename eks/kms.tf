resource "aws_kms_key" "secrets" {
  count = var.create_kms_key ? 1 : 0

  description             = "Criptografia de secrets do cluster EKS ${var.cluster_name}"
  enable_key_rotation     = true
  deletion_window_in_days = var.kms_key_deletion_window_in_days
  tags                    = var.tags
}

resource "aws_kms_alias" "secrets" {
  count = var.create_kms_key ? 1 : 0

  name          = "alias/eks/${var.cluster_name}"
  target_key_id = aws_kms_key.secrets[0].key_id
}
