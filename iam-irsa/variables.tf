variable "name" {
  description = "Nome da IAM role criada e prefixo dos recursos."
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN do OIDC provider do cluster EKS (output oidc_provider_arn do módulo eks)."
  type        = string
}

variable "oidc_provider_url" {
  description = "URL do issuer OIDC do cluster, sem o prefixo https:// (output oidc_provider_url do módulo eks)."
  type        = string
}

variable "namespace" {
  description = "Namespace Kubernetes do(s) service account(s) que assumirá(ão) a role."
  type        = string
}

variable "service_accounts" {
  description = "Service accounts no namespace autorizados a assumir a role. Use [\"*\"] para qualquer SA do namespace."
  type        = list(string)

  validation {
    condition     = length(var.service_accounts) > 0
    error_message = "Informe ao menos um service account (ou [\"*\"] para todos do namespace)."
  }
}

variable "policy_json" {
  description = "Documento de política IAM (JSON) anexado inline à role. Null para não anexar policy inline."
  type        = string
  default     = null
}

variable "policy_arns" {
  description = "ARNs de managed policies existentes a anexar à role. Use ARNs conhecidos no plan (evite valores known-after-apply)."
  type        = list(string)
  default     = []
}

variable "max_session_duration" {
  description = "Duração máxima da sessão da role, em segundos (3600–43200)."
  type        = number
  default     = 3600
}

# ── SSM Parameter Store (publicação do ARN da role) ───────────────────────────

variable "create_ssm_parameter" {
  description = "Publica o ARN da role no SSM Parameter Store, para pipelines/manifests lerem sem acessar o tfstate."
  type        = bool
  default     = false
}

variable "ssm_parameter_name" {
  description = "Nome do parâmetro SSM com o ARN da role. Quando nulo e create_ssm_parameter for true, usa /irsa/<name>/role-arn."
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags aplicadas a todos os recursos criados pelo módulo."
  type        = map(string)
  default     = {}
}
