resource "helm_release" "keda" {
  count = var.enable_keda ? 1 : 0

  name       = "keda"
  namespace  = var.keda_namespace
  repository = "https://kedacore.github.io/charts"
  chart      = "keda"
  version    = var.keda_chart_version

  # KEDA não tem permissões AWS genéricas: quando um scaler usa AWS (ex.: SQS), a
  # IRSA do keda-operator é responsabilidade do consumidor, injetada via helm values
  # (anotação eks.amazonaws.com/role-arn no serviceAccount.operator). Mesmo padrão
  # do external-secrets.
  values = var.keda_helm_values

  depends_on = [kubernetes_namespace_v1.keda]
}
