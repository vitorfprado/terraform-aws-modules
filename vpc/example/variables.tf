variable "region" {
  description = "Região AWS onde a VPC será provisionada."
  type        = string
  default     = "us-east-1"
}

variable "name" {
  description = "Nome base da VPC."
  type        = string
  default     = "demo"
}

variable "cidr_block" {
  description = "Bloco CIDR primário da VPC."
  type        = string
  default     = "10.0.0.0/16"
}
