variable "region" {
  description = "Região AWS."
  type        = string
  default     = "us-east-1"
}

variable "db_password" {
  description = "Senha do banco (exemplo) — em uso real, gere com random_password."
  type        = string
  default     = "trocar-esta-senha"
  sensitive   = true
}

variable "api_key" {
  description = "API key de exemplo."
  type        = string
  default     = "exemplo-api-key"
  sensitive   = true
}
