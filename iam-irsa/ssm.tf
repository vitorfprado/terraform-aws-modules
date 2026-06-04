locals {
  ssm_parameter_name = coalesce(var.ssm_parameter_name, "/irsa/${var.name}/role-arn")
}

# Publica o ARN da role no Parameter Store. Útil para a geração dos manifests
# (annotation eks.amazonaws.com/role-arn no ServiceAccount) e para pipelines
# resolverem o ARN sem ler o tfstate.
resource "aws_ssm_parameter" "role_arn" {
  count = var.create_ssm_parameter ? 1 : 0

  name        = local.ssm_parameter_name
  description = "ARN da IRSA role ${var.name}."
  type        = "String"
  value       = aws_iam_role.irsa.arn

  tags = merge(var.tags, { Name = local.ssm_parameter_name })
}
