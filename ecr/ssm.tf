locals {
  ssm_prefix = coalesce(var.ssm_parameter_prefix, "/ecr")
}

# A URL do repositório é o destino do docker push. Publicá-la no Parameter Store
# permite que a esteira a resolva sem ler o tfstate nem montar o endereço na mão
# a partir de account id e região.
resource "aws_ssm_parameter" "repository_url" {
  for_each = var.create_ssm_parameters ? local.repositories : {}

  name        = "${local.ssm_prefix}/${each.key}/repository-url"
  description = "URL do repositório ECR ${each.value}."
  type        = "String"
  value       = aws_ecr_repository.main[each.key].repository_url

  tags = merge(var.tags, { Name = "${local.ssm_prefix}/${each.key}/repository-url" })
}
