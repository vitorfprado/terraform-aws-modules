variable "name" {
  description = "Nome do secret no Secrets Manager (ex.: togglemaster/rds/auth)."
  type        = string
}

variable "description" {
  description = "Descrição do secret. Quando nula, é gerada a partir do name."
  type        = string
  default     = null
}

variable "secret_string" {
  description = "Conteúdo do secret como string única. Mutuamente exclusivo com secret_key_value."
  type        = string
  default     = null
  sensitive   = true
}

variable "secret_key_value" {
  description = "Conteúdo do secret como mapa key/value, serializado em JSON. Use para secrets multi-campo (ex.: connection_string + host + username). Mutuamente exclusivo com secret_string."
  type        = map(string)
  default     = null
  sensitive   = true
}

variable "recovery_window_in_days" {
  description = "Dias de janela de recuperação antes da exclusão definitiva. 0 exclui imediatamente (adequado para lab)."
  type        = number
  default     = 30
}

variable "create_kms_key" {
  description = "Cria uma KMS key dedicada para o secret. Caso contrário, usa a key gerenciada padrão do Secrets Manager (aws/secretsmanager)."
  type        = bool
  default     = false
}

variable "kms_key_arn" {
  description = "ARN de uma KMS key existente para criptografar o secret. Quando nulo e create_kms_key for false, usa a key padrão do serviço."
  type        = string
  default     = null
}

variable "kms_key_deletion_window_in_days" {
  description = "Janela de espera, em dias, antes da exclusão definitiva da KMS key criada pelo módulo."
  type        = number
  default     = 30
}

variable "tags" {
  description = "Tags aplicadas a todos os recursos criados pelo módulo."
  type        = map(string)
  default     = {}
}
