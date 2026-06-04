variable "name" {
  description = "Nome da tabela DynamoDB."
  type        = string
}

variable "billing_mode" {
  description = "Modo de cobrança: PAY_PER_REQUEST (on-demand, escala sozinho) ou PROVISIONED (capacidade fixa)."
  type        = string
  default     = "PAY_PER_REQUEST"

  validation {
    condition     = contains(["PAY_PER_REQUEST", "PROVISIONED"], var.billing_mode)
    error_message = "billing_mode deve ser PAY_PER_REQUEST ou PROVISIONED."
  }
}

variable "hash_key" {
  description = "Nome do atributo usado como partition key (hash key)."
  type        = string
}

variable "range_key" {
  description = "Nome do atributo usado como sort key (range key). Opcional."
  type        = string
  default     = null
}

variable "attributes" {
  description = "Atributos usados como chave (da tabela, GSIs e LSIs). Apenas atributos-chave precisam ser declarados. type: S (string), N (number) ou B (binary)."
  type = list(object({
    name = string
    type = string
  }))
}

variable "read_capacity" {
  description = "Capacidade de leitura provisionada (RCU). Obrigatório quando billing_mode for PROVISIONED."
  type        = number
  default     = null
}

variable "write_capacity" {
  description = "Capacidade de escrita provisionada (WCU). Obrigatório quando billing_mode for PROVISIONED."
  type        = number
  default     = null
}

variable "table_class" {
  description = "Classe da tabela: STANDARD ou STANDARD_INFREQUENT_ACCESS."
  type        = string
  default     = "STANDARD"
}

variable "global_secondary_indexes" {
  description = "Índices secundários globais (GSI). read_capacity/write_capacity só se aplicam em billing_mode PROVISIONED."
  type = list(object({
    name               = string
    hash_key           = string
    range_key          = optional(string)
    projection_type    = optional(string, "ALL")
    non_key_attributes = optional(list(string))
    read_capacity      = optional(number)
    write_capacity     = optional(number)
  }))
  default = []
}

variable "local_secondary_indexes" {
  description = "Índices secundários locais (LSI). Compartilham a hash key da tabela e devem ser definidos na criação."
  type = list(object({
    name               = string
    range_key          = string
    projection_type    = optional(string, "ALL")
    non_key_attributes = optional(list(string))
  }))
  default = []
}

variable "ttl_enabled" {
  description = "Habilita o Time To Live (expiração automática de itens)."
  type        = bool
  default     = false
}

variable "ttl_attribute_name" {
  description = "Nome do atributo (timestamp epoch) que define o TTL dos itens. Obrigatório quando ttl_enabled for true."
  type        = string
  default     = null
}

variable "point_in_time_recovery_enabled" {
  description = "Habilita o Point-in-Time Recovery (restauração contínua dos últimos 35 dias)."
  type        = bool
  default     = true
}

variable "stream_enabled" {
  description = "Habilita o DynamoDB Streams (captura de alterações na tabela)."
  type        = bool
  default     = false
}

variable "stream_view_type" {
  description = "O que os registros do stream contêm: KEYS_ONLY, NEW_IMAGE, OLD_IMAGE ou NEW_AND_OLD_IMAGES. Obrigatório quando stream_enabled for true."
  type        = string
  default     = null
}

variable "server_side_encryption_enabled" {
  description = "Habilita a criptografia gerenciada por KMS. Quando false, a tabela ainda é criptografada com a chave própria da AWS (sem custo)."
  type        = bool
  default     = false
}

variable "create_kms_key" {
  description = "Cria uma KMS key dedicada para a criptografia. Ignorado se server_side_encryption_enabled for false ou kms_key_arn for informado."
  type        = bool
  default     = true
}

variable "kms_key_arn" {
  description = "ARN de uma KMS key existente. Quando nulo e create_kms_key for false, usa a key gerenciada aws/dynamodb."
  type        = string
  default     = null
}

variable "kms_key_deletion_window_in_days" {
  description = "Janela de espera, em dias, antes da exclusão definitiva da KMS key criada pelo módulo."
  type        = number
  default     = 30
}

variable "deletion_protection_enabled" {
  description = "Impede a exclusão acidental da tabela. Recomendado true em produção."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags aplicadas a todos os recursos criados pelo módulo."
  type        = map(string)
  default     = {}
}
