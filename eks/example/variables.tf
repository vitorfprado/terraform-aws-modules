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

variable "admin_role_arn" {
  description = "ARN do principal IAM que receberá acesso de administrador do cluster."
  type        = string
}
