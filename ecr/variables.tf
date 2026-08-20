variable "repository_names" {
  description = "Nomes dos repositórios a criar. Um módulo cria vários porque eles compartilham configuração (scan, lifecycle, criptografia) e uma única KMS key."
  type        = list(string)

  validation {
    condition     = length(var.repository_names) > 0
    error_message = "Informe ao menos um repositório."
  }
}

variable "namespace" {
  description = "Namespace opcional prefixado a cada repositório (ex.: \"togglemaster\" gera togglemaster/auth-service). Quando nulo, os nomes são usados como estão."
  type        = string
  default     = null
}

variable "image_tag_mutability" {
  description = "MUTABLE permite sobrescrever uma tag existente; IMMUTABLE não. O padrão é IMMUTABLE — com tags derivadas do commit, uma tag deve apontar para sempre à mesma imagem."
  type        = string
  default     = "IMMUTABLE"

  validation {
    condition     = contains(["MUTABLE", "IMMUTABLE"], var.image_tag_mutability)
    error_message = "image_tag_mutability deve ser MUTABLE ou IMMUTABLE."
  }
}

variable "scan_on_push" {
  description = "Dispara o scan básico de vulnerabilidades a cada push de imagem."
  type        = bool
  default     = true
}

variable "force_delete" {
  description = "Permite destruir um repositório que ainda contém imagens. Perigoso fora de ambientes efêmeros."
  type        = bool
  default     = false
}

# ── Criptografia ──────────────────────────────────────────────────────────────

variable "encryption_type" {
  description = "AES256 usa chaves gerenciadas pela AWS, sem custo. KMS permite chave própria, com auditoria em CloudTrail e controle de acesso via key policy."
  type        = string
  default     = "AES256"

  validation {
    condition     = contains(["AES256", "KMS"], var.encryption_type)
    error_message = "encryption_type deve ser AES256 ou KMS."
  }
}

variable "create_kms_key" {
  description = "Cria uma KMS key dedicada, compartilhada por todos os repositórios do módulo. Só tem efeito quando encryption_type é KMS e kms_key_arn é nulo."
  type        = bool
  default     = false
}

variable "kms_key_arn" {
  description = "ARN de uma KMS key existente. Tem precedência sobre create_kms_key."
  type        = string
  default     = null
}

variable "kms_key_deletion_window_in_days" {
  description = "Janela de espera antes da exclusão definitiva da KMS key criada (7–30 dias)."
  type        = number
  default     = 30
}

# ── Lifecycle policy ──────────────────────────────────────────────────────────

variable "create_lifecycle_policy" {
  description = "Aplica uma lifecycle policy aos repositórios. Sem ela, toda imagem publicada fica armazenada (e cobrada) para sempre."
  type        = bool
  default     = true
}

variable "untagged_image_expiration_days" {
  description = "Dias até expirar imagens sem tag. Elas surgem quando uma tag é reapontada ou um build multi-arch é sobrescrito, e não têm valor de rollback."
  type        = number
  default     = 7
}

variable "max_tagged_images" {
  description = "Quantidade de imagens com tag a manter por repositório. As mais antigas além desse número expiram."
  type        = number
  default     = 30
}

variable "lifecycle_tag_prefixes" {
  description = "Quando informado, a regra de retenção só considera tags com esses prefixos (ex.: [\"v\"]). Lista vazia aplica a regra a todas as imagens com tag."
  type        = list(string)
  default     = []
}

variable "lifecycle_policy" {
  description = "Documento JSON de lifecycle policy completo. Quando informado, substitui as regras geradas pelas variáveis acima."
  type        = string
  default     = null
}

# ── Repository policy ─────────────────────────────────────────────────────────

variable "repository_policies" {
  description = "Policies de repositório por nome, no formato { \"<nome>\" = \"<json>\" }. Use para permitir pull de outra conta. A chave deve constar em repository_names."
  type        = map(string)
  default     = {}
}

# ── SSM Parameter Store ───────────────────────────────────────────────────────

variable "create_ssm_parameters" {
  description = "Publica a URL de cada repositório no Parameter Store, para pipelines resolverem o destino do push sem acessar o tfstate."
  type        = bool
  default     = false
}

variable "ssm_parameter_prefix" {
  description = "Prefixo dos parâmetros SSM. Quando nulo, usa /ecr."
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags aplicadas a todos os recursos criados pelo módulo."
  type        = map(string)
  default     = {}
}
