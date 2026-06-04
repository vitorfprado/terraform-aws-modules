variable "region" {
  description = "Região AWS onde a fila será provisionada."
  type        = string
  default     = "us-east-1"
}

variable "name" {
  description = "Nome da fila."
  type        = string
  default     = "demo-jobs"
}
