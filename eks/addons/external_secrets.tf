resource "helm_release" "external_secrets" {
  count = var.enable_external_secrets ? 1 : 0

  name       = "external-secrets"
  namespace  = var.external_secrets_namespace
  repository = "https://charts.external-secrets.io"
  chart      = "external-secrets"
  version    = var.external_secrets_chart_version

  set = [
    { name = "installCRDs", value = tostring(var.external_secrets_install_crds) },
  ]

  values = var.external_secrets_helm_values

  depends_on = [kubernetes_namespace_v1.external_secrets]
}
