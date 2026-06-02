output "enabled_addons" {
  description = "Mapa indicando quais add-ons foram habilitados nesta instância do submódulo."
  value = {
    metrics_server               = var.enable_metrics_server
    aws_load_balancer_controller = var.enable_aws_load_balancer_controller
    cert_manager                 = var.enable_cert_manager
    external_secrets             = var.enable_external_secrets
    kube_prometheus_stack        = var.enable_kube_prometheus_stack
    argocd                       = var.enable_argocd
  }
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
  }
}
