variable "region" {
  description = "Região AWS onde o cluster será provisionado."
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "Nome do cluster EKS."
  type        = string
  default     = "demo"
}

variable "cluster_version" {
  description = "Versão do Kubernetes do control plane."
  type        = string
  default     = "1.32"
}

variable "vpc_id" {
  description = "ID da VPC onde o cluster será criado."
  type        = string
}

variable "subnet_ids" {
  description = "IDs das subnets (preferencialmente privadas) para o cluster e os node groups."
  type        = list(string)
}

variable "admin_role_arn" {
  description = "ARN do principal IAM que receberá acesso de administrador do cluster."
  type        = string
}

variable "enable_metrics_server" {
  description = "Instala o Metrics Server via Helm."
  type        = bool
  default     = false
}

variable "enable_aws_load_balancer_controller" {
  description = "Instala o AWS Load Balancer Controller (com IRSA) via Helm."
  type        = bool
  default     = false
}

variable "enable_cert_manager" {
  description = "Instala o cert-manager via Helm."
  type        = bool
  default     = false
}

variable "enable_external_secrets" {
  description = "Instala o External Secrets Operator via Helm."
  type        = bool
  default     = false
}

variable "enable_kube_prometheus_stack" {
  description = "Instala o kube-prometheus-stack via Helm."
  type        = bool
  default     = false
}

variable "enable_argocd" {
  description = "Instala o Argo CD via Helm."
  type        = bool
  default     = false
}
