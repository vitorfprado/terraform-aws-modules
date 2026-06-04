variable "region" {
  description = "Região AWS onde a tabela será provisionada."
  type        = string
  default     = "us-east-1"
}

variable "name" {
  description = "Nome da tabela."
  type        = string
  default     = "demo-orders"
}
