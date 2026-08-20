variable "cluster_name" {
  description = "Nome do cluster EKS. Entra no nome padrão da role e no clusterName do chart."
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN do OIDC provider do cluster (output oidc_provider_arn do módulo eks). Necessário para IRSA."
  type        = string
}

variable "oidc_provider_url" {
  description = "URL do issuer OIDC do cluster, com ou sem o prefixo https:// (output oidc_provider_url do módulo eks)."
  type        = string
}

variable "vpc_id" {
  description = "ID da VPC do cluster. O controller precisa dele para descobrir subnets ao criar ALB/NLB."
  type        = string
}

variable "region" {
  description = "Região AWS do cluster. Quando nulo, é resolvida pelo provider."
  type        = string
  default     = null
}

# ── Vínculo com o service account ─────────────────────────────────────────────

variable "namespace" {
  description = "Namespace onde o controller roda. O chart instala em kube-system por padrão."
  type        = string
  default     = "kube-system"
}

variable "service_account_name" {
  description = "Nome do service account do controller. Precisa bater com o serviceAccount.name usado na instalação do chart."
  type        = string
  default     = "aws-load-balancer-controller"
}

variable "role_name" {
  description = "Nome da IAM role (IRSA). Quando nulo, usa <cluster_name>-aws-lb-controller."
  type        = string
  default     = null
}

# ── SSM Parameter Store ───────────────────────────────────────────────────────

variable "create_ssm_parameters" {
  description = "Publica o ARN da role no Parameter Store, para a camada de manifests lê-lo sem acessar o tfstate."
  type        = bool
  default     = false
}

variable "ssm_parameter_prefix" {
  description = "Prefixo dos parâmetros SSM. Quando nulo, usa /aws-lb-controller/<cluster_name>."
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags aplicadas a todos os recursos criados pelo módulo."
  type        = map(string)
  default     = {}
}
