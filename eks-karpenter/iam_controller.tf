# A trust policy IRSA vem do módulo iam-irsa (caminho relativo: quem pinar este
# módulo em uma tag recebe a mesma versão do iam-irsa, sem resolver ?ref).
module "controller_role" {
  source = "../iam-irsa"

  name              = local.controller_role_name
  oidc_provider_arn = var.oidc_provider_arn
  oidc_provider_url = var.oidc_provider_url

  namespace        = var.namespace
  service_accounts = [var.service_account_name]

  # Inline (limite de 10.240 chars) e não managed policy (6.144): o documento do
  # Karpenter é grande e fica apertado como managed.
  inline_policies = {
    controller = templatefile("${path.module}/policies/karpenter_controller_iam_policy.json.tftpl", {
      partition              = local.partition
      region                 = local.region
      account_id             = local.account_id
      cluster_name           = var.cluster_name
      node_role_arn          = aws_iam_role.node.arn
      interruption_queue_arn = aws_sqs_queue.interruption.arn
    })
  }

  tags = var.tags
}
