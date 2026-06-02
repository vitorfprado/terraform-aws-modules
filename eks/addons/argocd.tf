resource "helm_release" "argocd" {
  count = var.enable_argocd ? 1 : 0

  name       = "argo-cd"
  namespace  = var.argocd_namespace
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.argocd_chart_version

  values = var.argocd_helm_values

  depends_on = [kubernetes_namespace_v1.argocd]
}
