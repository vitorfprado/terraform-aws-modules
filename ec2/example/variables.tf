variable "region" {
  description = "Região AWS onde os recursos serão provisionados."
  type        = string
  default     = "us-east-1"
}

variable "name" {
  description = "Nome base usado pela VPC e pela instância."
  type        = string
  default     = "demo"
}
