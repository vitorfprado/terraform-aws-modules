locals {
  ssm_prefix = coalesce(var.ssm_parameter_prefix, "/aws-lb-controller/${var.cluster_name}")

  ssm_parameters = var.create_ssm_parameters ? {
    "role-arn" = {
      value       = module.role.role_arn
      description = "ARN da IRSA role do AWS Load Balancer Controller (annotation eks.amazonaws.com/role-arn)."
    }
  } : {}
}

resource "aws_ssm_parameter" "lb_controller" {
  for_each = local.ssm_parameters

  name        = "${local.ssm_prefix}/${each.key}"
  description = each.value.description
  type        = "String"
  value       = each.value.value

  tags = merge(var.tags, { Name = "${local.ssm_prefix}/${each.key}" })
}
