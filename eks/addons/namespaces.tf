resource "kubernetes_namespace_v1" "cert_manager" {
  count = var.enable_cert_manager ? 1 : 0

  metadata {
    name = var.cert_manager_namespace
  }
}

resource "kubernetes_namespace_v1" "external_secrets" {
  count = var.enable_external_secrets ? 1 : 0

  metadata {
    name = var.external_secrets_namespace
  }
}

resource "kubernetes_namespace_v1" "monitoring" {
  count = var.enable_kube_prometheus_stack ? 1 : 0

  metadata {
    name = var.kube_prometheus_stack_namespace
  }
}

resource "kubernetes_namespace_v1" "argocd" {
  count = var.enable_argocd ? 1 : 0

  metadata {
    name = var.argocd_namespace
  }
}

resource "kubernetes_namespace_v1" "keda" {
  count = var.enable_keda ? 1 : 0

  metadata {
    name = var.keda_namespace
  }
}
