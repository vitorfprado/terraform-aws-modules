# As regras são codificadas UMA A UMA e só depois unidas como texto.
#
# O caminho natural — montar a lista de regras e chamar jsonencode no conjunto —
# não funciona aqui. As duas regras têm formatos de objeto diferentes (a de
# imagens sem tag tem countUnit, a de retenção não), e nesse caso o Terraform
# unifica os elementos para um tipo comum: map(string). O efeito é countNumber
# virar "7" em vez de 7, e o ECR rejeitar a policy — countNumber é integer no
# schema dele.
#
# Codificando cada regra separadamente, cada jsonencode recebe um objeto de
# formato fixo e os números são preservados.
locals {
  restrict_by_prefix = length(var.lifecycle_tag_prefixes) > 0

  # Imagens sem tag: surgem quando uma tag é reapontada ou um build é
  # sobrescrito. Não servem para rollback e só ocupam espaço.
  untagged_rule = var.untagged_image_expiration_days > 0 ? [jsonencode({
    rulePriority = 1
    description  = "Expira imagens sem tag apos ${var.untagged_image_expiration_days} dias"
    selection = {
      tagStatus   = "untagged"
      countType   = "sinceImagePushed"
      countUnit   = "days"
      countNumber = var.untagged_image_expiration_days
    }
    action = { type = "expire" }
  })] : []

  # A prioridade não pode ser fixa: a regra acima é opcional, então esta é a 1
  # quando ela não existe e a 2 quando existe. A lista tem zero ou um elemento e
  # serve de contador.
  retention_priority = length(local.untagged_rule) + 1

  # Duas variantes completas em vez de um objeto com campo condicional: o ECR
  # exige tagPrefixList não vazio quando tagStatus é "tagged", e o proíbe quando
  # é "any" — os dois casos são documentos diferentes, não um com um campo a mais.
  #
  # A regra "any" precisa ser a de maior rulePriority; como ela é sempre a
  # última das duas, isso está garantido.
  retention_rule = var.max_tagged_images > 0 ? [
    local.restrict_by_prefix ? jsonencode({
      rulePriority = local.retention_priority
      description  = "Mantem as ${var.max_tagged_images} imagens mais recentes"
      selection = {
        tagStatus     = "tagged"
        tagPrefixList = var.lifecycle_tag_prefixes
        countType     = "imageCountMoreThan"
        countNumber   = var.max_tagged_images
      }
      action = { type = "expire" }
      }) : jsonencode({
      rulePriority = local.retention_priority
      description  = "Mantem as ${var.max_tagged_images} imagens mais recentes"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = var.max_tagged_images
      }
      action = { type = "expire" }
    })
  ] : []

  rule_documents             = concat(local.untagged_rule, local.retention_rule)
  generated_lifecycle_policy = format("{\"rules\":[%s]}", join(",", local.rule_documents))

  effective_lifecycle_policy = coalesce(var.lifecycle_policy, local.generated_lifecycle_policy)

  # Com as duas variáveis em zero a policy gerada seria {"rules":[]}, que o ECR
  # rejeita. Em vez de deixar o apply falhar com erro de API, não criamos o recurso.
  apply_lifecycle_policy = var.create_lifecycle_policy && (
    var.lifecycle_policy != null || length(local.rule_documents) > 0
  )
}

resource "aws_ecr_lifecycle_policy" "main" {
  for_each = local.apply_lifecycle_policy ? local.repositories : {}

  repository = aws_ecr_repository.main[each.key].name
  policy     = local.effective_lifecycle_policy
}
