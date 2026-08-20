variable "region" {
  description = "Região AWS."
  type        = string
  default     = "us-east-1"
}

variable "namespace" {
  description = "Namespace dos repositórios (prefixo antes da barra)."
  type        = string
  default     = "togglemaster"
}
