variable "cluster_name" {
  description = "Nome do cluster EKS onde os add-ons serão instalados."
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN do OIDC provider do cluster (output oidc_provider_arn do módulo eks). Necessário para IRSA."
  type        = string
}

variable "oidc_provider_url" {
  description = "URL do issuer OIDC do cluster, com ou sem o prefixo https:// (output oidc_provider_url do módulo eks)."
  type        = string
}

variable "vpc_id" {
  description = "ID da VPC do cluster. Usado pelo AWS Load Balancer Controller."
  type        = string
}

variable "region" {
  description = "Região AWS do cluster. Quando nulo, é resolvida automaticamente pelo provider."
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags aplicadas aos recursos IAM criados pelo submódulo."
  type        = map(string)
  default     = {}
}

variable "enable_metrics_server" {
  description = "Instala o Metrics Server (necessário para HPA e kubectl top)."
  type        = bool
  default     = false
}

variable "metrics_server_chart_version" {
  description = "Versão do chart Helm do Metrics Server."
  type        = string
  default     = "3.12.2"
}

variable "metrics_server_helm_values" {
  description = "Lista de documentos YAML (raw) com valores adicionais para o chart do Metrics Server."
  type        = list(string)
  default     = []
}

variable "enable_aws_load_balancer_controller" {
  description = "Instala o AWS Load Balancer Controller, incluindo a IAM role (IRSA) e a policy dedicada."
  type        = bool
  default     = false
}

variable "aws_load_balancer_controller_chart_version" {
  description = "Versão do chart Helm do AWS Load Balancer Controller."
  type        = string
  default     = "1.8.1"
}

variable "aws_load_balancer_controller_helm_values" {
  description = "Lista de documentos YAML (raw) com valores adicionais para o chart do AWS Load Balancer Controller."
  type        = list(string)
  default     = []
}

variable "enable_cert_manager" {
  description = "Instala o cert-manager no namespace dedicado."
  type        = bool
  default     = false
}

variable "cert_manager_chart_version" {
  description = "Versão do chart Helm do cert-manager."
  type        = string
  default     = "v1.15.3"
}

variable "cert_manager_namespace" {
  description = "Namespace onde o cert-manager será instalado."
  type        = string
  default     = "cert-manager"
}

variable "cert_manager_install_crds" {
  description = "Instala os CRDs do cert-manager junto com o chart."
  type        = bool
  default     = true
}

variable "cert_manager_helm_values" {
  description = "Lista de documentos YAML (raw) com valores adicionais para o chart do cert-manager."
  type        = list(string)
  default     = []
}

variable "enable_external_secrets" {
  description = "Instala o External Secrets Operator no namespace dedicado."
  type        = bool
  default     = false
}

variable "external_secrets_chart_version" {
  description = "Versão do chart Helm do External Secrets Operator."
  type        = string
  default     = "0.10.4"
}

variable "external_secrets_namespace" {
  description = "Namespace onde o External Secrets Operator será instalado."
  type        = string
  default     = "external-secrets"
}

variable "external_secrets_install_crds" {
  description = "Instala os CRDs do External Secrets Operator junto com o chart."
  type        = bool
  default     = true
}

variable "external_secrets_helm_values" {
  description = "Lista de documentos YAML (raw) com valores adicionais para o chart do External Secrets Operator."
  type        = list(string)
  default     = []
}

variable "enable_keda" {
  description = "Instala o KEDA (Kubernetes Event-driven Autoscaling) no namespace dedicado. A IRSA do keda-operator (quando usa scalers AWS) fica a cargo do consumidor, via keda_helm_values."
  type        = bool
  default     = false
}

variable "keda_chart_version" {
  description = "Versão do chart Helm do KEDA (repo kedacore)."
  type        = string
  default     = "2.18.3"
}

variable "keda_namespace" {
  description = "Namespace onde o KEDA será instalado."
  type        = string
  default     = "keda"
}

variable "keda_helm_values" {
  description = "Lista de documentos YAML (raw) com valores adicionais para o chart do KEDA (ex.: anotação IRSA no serviceAccount.operator)."
  type        = list(string)
  default     = []
}

variable "enable_kube_prometheus_stack" {
  description = "Instala o kube-prometheus-stack (Prometheus, Alertmanager e Grafana) no namespace dedicado."
  type        = bool
  default     = false
}

variable "kube_prometheus_stack_chart_version" {
  description = "Versão do chart Helm do kube-prometheus-stack."
  type        = string
  default     = "62.7.0"
}

variable "kube_prometheus_stack_namespace" {
  description = "Namespace onde o kube-prometheus-stack será instalado."
  type        = string
  default     = "monitoring"
}

variable "kube_prometheus_stack_helm_values" {
  description = "Lista de documentos YAML (raw) com valores adicionais para o chart do kube-prometheus-stack."
  type        = list(string)
  default     = []
}

variable "enable_argocd" {
  description = "Instala o Argo CD no namespace dedicado."
  type        = bool
  default     = false
}

variable "enable_karpenter" {
  description = "Instala o Karpenter, incluindo IRSA do controller, IAM role e access entry dos nós, fila SQS de interrupção e regras do EventBridge."
  type        = bool
  default     = false
}

variable "karpenter_chart_version" {
  description = "Versão do chart Helm do Karpenter (OCI public.ecr.aws/karpenter). Para Karpenter v1+ a versão do chart coincide com a do app (ex.: \"1.1.1\")."
  type        = string
  default     = "1.1.1"
}

variable "karpenter_namespace" {
  description = "Namespace onde o Karpenter será instalado. O padrão recomendado no v1 é kube-system."
  type        = string
  default     = "kube-system"
}

variable "karpenter_helm_values" {
  description = "Lista de documentos YAML (raw) com valores adicionais para o chart do Karpenter."
  type        = list(string)
  default     = []
}

variable "argocd_chart_version" {
  description = "Versão do chart Helm do Argo CD."
  type        = string
  default     = "7.6.12"
}

variable "argocd_namespace" {
  description = "Namespace onde o Argo CD será instalado."
  type        = string
  default     = "argocd"
}

variable "argocd_helm_values" {
  description = "Lista de documentos YAML (raw) com valores adicionais para o chart do Argo CD."
  type        = list(string)
  default     = []
}
