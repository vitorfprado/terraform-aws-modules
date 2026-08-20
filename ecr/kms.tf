# Uma única chave para todos os repositórios do módulo. KMS é cobrada por chave
# por mês, e não há ganho de isolamento em ter uma por repositório quando todos
# pertencem ao mesmo sistema.
resource "aws_kms_key" "ecr" {
  count = local.create_kms_key_resource ? 1 : 0

  description             = "Criptografia dos repositórios ECR ${coalesce(var.namespace, join(", ", var.repository_names))}"
  enable_key_rotation     = true
  deletion_window_in_days = var.kms_key_deletion_window_in_days

  tags = var.tags
}

resource "aws_kms_alias" "ecr" {
  count = local.create_kms_key_resource ? 1 : 0

  name          = "alias/ecr/${coalesce(var.namespace, var.repository_names[0])}"
  target_key_id = aws_kms_key.ecr[0].key_id
}
