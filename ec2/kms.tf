resource "aws_kms_key" "ec2" {
  count = local.create_kms_key_resource ? 1 : 0

  description             = "Criptografia dos volumes EBS da instância ${var.name}"
  enable_key_rotation     = true
  deletion_window_in_days = var.kms_key_deletion_window_in_days
  tags                    = var.tags
}

resource "aws_kms_alias" "ec2" {
  count = local.create_kms_key_resource ? 1 : 0

  name          = "alias/ec2/${var.name}"
  target_key_id = aws_kms_key.ec2[0].key_id
}
