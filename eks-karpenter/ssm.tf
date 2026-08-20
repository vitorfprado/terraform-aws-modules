locals {
  ssm_prefix = coalesce(var.ssm_parameter_prefix, "/karpenter/${var.cluster_name}")

  # Os três valores que a instalação do chart e o EC2NodeClass precisam. Ficam no
  # Parameter Store para que a camada de manifests os leia sem tocar no tfstate.
  ssm_parameters = var.create_ssm_parameters ? {
    "controller-role-arn" = {
      value       = module.controller_role.role_arn
      description = "ARN da IRSA role do controller do Karpenter (annotation eks.amazonaws.com/role-arn)."
    }
    "node-role-name" = {
      value       = aws_iam_role.node.name
      description = "Nome da IAM role dos nós do Karpenter (spec.role do EC2NodeClass)."
    }
    "interruption-queue-name" = {
      value       = aws_sqs_queue.interruption.name
      description = "Nome da fila SQS de interrupção (settings.interruptionQueue do chart)."
    }
  } : {}
}

resource "aws_ssm_parameter" "karpenter" {
  for_each = local.ssm_parameters

  name        = "${local.ssm_prefix}/${each.key}"
  description = each.value.description
  type        = "String"
  value       = each.value.value

  tags = merge(var.tags, { Name = "${local.ssm_prefix}/${each.key}" })
}
