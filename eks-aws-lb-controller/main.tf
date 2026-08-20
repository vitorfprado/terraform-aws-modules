data "aws_region" "current" {}

locals {
  # .name e não .region: o atributo region só existe no provider AWS 6+, e este
  # módulo declara >= 5.40. O name está deprecado no 6 mas continua funcionando,
  # então é o único que atende a faixa inteira. Revisar quando a biblioteca subir
  # o piso para 6.
  region    = coalesce(var.region, data.aws_region.current.name)
  role_name = coalesce(var.role_name, "${var.cluster_name}-aws-lb-controller")
}

# A policy é a publicada pelo projeto aws-load-balancer-controller, mantida
# verbatim em policies/ para facilitar o diff quando o upstream atualizar.
module "role" {
  source = "../iam-irsa"

  name              = local.role_name
  oidc_provider_arn = var.oidc_provider_arn
  oidc_provider_url = var.oidc_provider_url

  namespace        = var.namespace
  service_accounts = [var.service_account_name]

  inline_policies = {
    controller = file("${path.module}/policies/aws_lbc_iam_policy.json")
  }

  tags = var.tags
}
