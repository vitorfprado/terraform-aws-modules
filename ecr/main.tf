locals {
  # for_each sobre um map cujas CHAVES são os nomes curtos: o endereço no state
  # fica aws_ecr_repository.main["auth-service"], estável e legível. O valor é o
  # nome completo, já com o namespace.
  repositories = {
    for name in var.repository_names :
    name => var.namespace != null ? "${var.namespace}/${name}" : name
  }

  use_kms                 = var.encryption_type == "KMS"
  create_kms_key_resource = local.use_kms && var.create_kms_key && var.kms_key_arn == null
  kms_key_arn             = var.kms_key_arn != null ? var.kms_key_arn : (local.create_kms_key_resource ? aws_kms_key.ecr[0].arn : null)
}

resource "aws_ecr_repository" "main" {
  for_each = local.repositories

  name                 = each.value
  image_tag_mutability = var.image_tag_mutability
  force_delete         = var.force_delete

  image_scanning_configuration {
    scan_on_push = var.scan_on_push
  }

  encryption_configuration {
    encryption_type = var.encryption_type
    # kms_key só é aceito quando encryption_type é KMS; nulo deixa a AWS usar a
    # chave gerenciada padrão do ECR.
    kms_key = local.use_kms ? local.kms_key_arn : null
  }

  tags = merge(var.tags, { Name = each.value })
}

resource "aws_ecr_repository_policy" "main" {
  for_each = var.repository_policies

  repository = aws_ecr_repository.main[each.key].name
  policy     = each.value
}
