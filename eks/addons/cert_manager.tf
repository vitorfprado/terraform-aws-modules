resource "helm_release" "cert_manager" {
  count = var.enable_cert_manager ? 1 : 0

  name       = "cert-manager"
  namespace  = var.cert_manager_namespace
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  version    = var.cert_manager_chart_version

  set = [
    { name = "crds.enabled", value = tostring(var.cert_manager_install_crds) },
  ]

  values = var.cert_manager_helm_values

  depends_on = [kubernetes_namespace_v1.cert_manager]
}
