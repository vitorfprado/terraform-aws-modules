variable "name" {
  description = "Nome base da VPC, usado como prefixo na nomeação dos recursos."
  type        = string
}

variable "cidr_block" {
  description = "Bloco CIDR primário da VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "azs" {
  description = "Zonas de disponibilidade a utilizar. Quando vazio, são selecionadas automaticamente conforme a quantidade de subnets."
  type        = list(string)
  default     = []
}

variable "public_subnet_cidrs" {
  description = "CIDRs das subnets públicas, uma por AZ na ordem informada. Lista vazia não cria subnets públicas."
  type        = list(string)
  default     = []
}

variable "private_subnet_cidrs" {
  description = "CIDRs das subnets privadas, uma por AZ na ordem informada. Lista vazia não cria subnets privadas."
  type        = list(string)
  default     = []
}

variable "enable_nat_gateway" {
  description = "Cria NAT Gateways para dar saída à internet às subnets privadas."
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Usa um único NAT Gateway para todas as subnets privadas (mais barato). Quando false, cria um NAT por AZ (alta disponibilidade)."
  type        = bool
  default     = false
}

variable "map_public_ip_on_launch" {
  description = "Atribui IP público automaticamente às instâncias lançadas nas subnets públicas."
  type        = bool
  default     = true
}

variable "enable_dns_support" {
  description = "Habilita resolução de DNS na VPC."
  type        = bool
  default     = true
}

variable "enable_dns_hostnames" {
  description = "Habilita nomes de host DNS na VPC. Necessário para EKS e diversos serviços."
  type        = bool
  default     = true
}

variable "public_subnet_tags" {
  description = "Tags adicionais aplicadas às subnets públicas (ex.: kubernetes.io/role/elb)."
  type        = map(string)
  default     = {}
}

variable "private_subnet_tags" {
  description = "Tags adicionais aplicadas às subnets privadas (ex.: kubernetes.io/role/internal-elb)."
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "Tags aplicadas a todos os recursos criados pelo módulo."
  type        = map(string)
  default     = {}
}
