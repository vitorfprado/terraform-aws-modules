# ── Controller ────────────────────────────────────────────────────────────────

output "controller_role_arn" {
  description = "ARN da IRSA role do controller. Vai na annotation eks.amazonaws.com/role-arn do service account do Karpenter."
  value       = module.controller_role.role_arn
}

output "controller_role_name" {
  description = "Nome da IRSA role do controller."
  value       = module.controller_role.role_name
}

output "service_account_name" {
  description = "Nome do service account esperado pela trust policy. Use o mesmo valor em serviceAccount.name na instalação do chart."
  value       = var.service_account_name
}

output "namespace" {
  description = "Namespace esperado pela trust policy do controller."
  value       = var.namespace
}

# ── Nós ───────────────────────────────────────────────────────────────────────

output "node_role_name" {
  description = "Nome da IAM role dos nós provisionados pelo Karpenter. É o valor de spec.role do EC2NodeClass."
  value       = aws_iam_role.node.name
}

output "node_role_arn" {
  description = "ARN da IAM role dos nós provisionados pelo Karpenter."
  value       = aws_iam_role.node.arn
}

# ── Interrupção ───────────────────────────────────────────────────────────────

output "interruption_queue_name" {
  description = "Nome da fila SQS de interrupção. É o valor de settings.interruptionQueue na instalação do chart."
  value       = aws_sqs_queue.interruption.name
}

output "interruption_queue_arn" {
  description = "ARN da fila SQS de interrupção."
  value       = aws_sqs_queue.interruption.arn
}

output "interruption_queue_url" {
  description = "URL da fila SQS de interrupção."
  value       = aws_sqs_queue.interruption.url
}

# ── SSM ───────────────────────────────────────────────────────────────────────

output "ssm_parameter_names" {
  description = "Nomes dos parâmetros publicados no Parameter Store, quando create_ssm_parameters é true."
  value       = { for k, v in aws_ssm_parameter.karpenter : k => v.name }
}

# ── Conveniência ──────────────────────────────────────────────────────────────

output "helm_values" {
  description = "Valores mínimos do chart do Karpenter que dependem desta infraestrutura. Útil para gerar values.yaml ou alimentar um helm_release fora do módulo."
  value = {
    settings = {
      clusterName       = var.cluster_name
      interruptionQueue = aws_sqs_queue.interruption.name
    }
    serviceAccount = {
      name = var.service_account_name
      annotations = {
        "eks.amazonaws.com/role-arn" = module.controller_role.role_arn
      }
    }
  }
}
