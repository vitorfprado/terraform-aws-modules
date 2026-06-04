variable "region" {
  description = "Região AWS."
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "Nome do cluster EKS (prefixo dos recursos do exemplo)."
  type        = string
  default     = "irsa-example"
}

variable "cluster_version" {
  description = "Versão do Kubernetes do cluster EKS."
  type        = string
  default     = "1.32"
}
