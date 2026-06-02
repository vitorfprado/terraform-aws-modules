resource "helm_release" "kube_prometheus_stack" {
  count = var.enable_kube_prometheus_stack ? 1 : 0

  name       = "kube-prometheus-stack"
  namespace  = var.kube_prometheus_stack_namespace
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = var.kube_prometheus_stack_chart_version

  values = var.kube_prometheus_stack_helm_values

  depends_on = [kubernetes_namespace_v1.monitoring]
}
