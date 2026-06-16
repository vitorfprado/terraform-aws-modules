output "enabled_addons" {
  description = "Mapa indicando quais add-ons foram habilitados nesta instância do submódulo."
  value = {
    metrics_server               = var.enable_metrics_server
    aws_load_balancer_controller = var.enable_aws_load_balancer_controller
    cert_manager                 = var.enable_cert_manager
    external_secrets             = var.enable_external_secrets
    kube_prometheus_stack        = var.enable_kube_prometheus_stack
    argocd                       = var.enable_argocd
    karpenter                    = var.enable_karpenter
    keda                         = var.enable_keda
  }
}

output "karpenter_node_iam_role_name" {
  description = "Nome da IAM role dos nós provisionados pelo Karpenter. Referencie-o no campo spec.role do EC2NodeClass."
  value       = try(aws_iam_role.karpenter_node[0].name, null)
}

output "karpenter_node_iam_role_arn" {
  description = "ARN da IAM role dos nós provisionados pelo Karpenter."
  value       = try(aws_iam_role.karpenter_node[0].arn, null)
}

output "karpenter_controller_iam_role_arn" {
  description = "ARN da IAM role (IRSA) do controller do Karpenter."
  value       = try(aws_iam_role.karpenter_controller[0].arn, null)
}

output "karpenter_interruption_queue_name" {
  description = "Nome da fila SQS usada pelo Karpenter para tratamento de interrupções."
  value       = try(aws_sqs_queue.karpenter[0].name, null)
}

output "aws_load_balancer_controller_iam_role_arn" {
  description = "ARN da IAM role (IRSA) criada para o AWS Load Balancer Controller."
  value       = try(aws_iam_role.aws_lbc[0].arn, null)
}

output "namespaces" {
  description = "Namespaces criados pelo submódulo para os add-ons com namespace dedicado."
  value = {
    cert_manager     = try(kubernetes_namespace_v1.cert_manager[0].metadata[0].name, null)
    external_secrets = try(kubernetes_namespace_v1.external_secrets[0].metadata[0].name, null)
    monitoring       = try(kubernetes_namespace_v1.monitoring[0].metadata[0].name, null)
    argocd           = try(kubernetes_namespace_v1.argocd[0].metadata[0].name, null)
    keda             = try(kubernetes_namespace_v1.keda[0].metadata[0].name, null)
  }
}
