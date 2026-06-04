variable "name" {
  description = "Nome da fila. Para filas FIFO, o sufixo .fifo é adicionado automaticamente se ausente."
  type        = string
}

variable "fifo_queue" {
  description = "Cria uma fila FIFO (ordem garantida e exactly-once) em vez de Standard."
  type        = bool
  default     = false
}

variable "content_based_deduplication" {
  description = "Habilita deduplicação baseada no conteúdo da mensagem. Aplicável apenas a filas FIFO."
  type        = bool
  default     = false
}

variable "deduplication_scope" {
  description = "Escopo da deduplicação em filas FIFO: \"messageGroup\" ou \"queue\". Aplicável apenas a filas FIFO."
  type        = string
  default     = null
}

variable "fifo_throughput_limit" {
  description = "Limite de throughput em filas FIFO: \"perQueue\" ou \"perMessageGroupId\". Aplicável apenas a filas FIFO."
  type        = string
  default     = null
}

variable "visibility_timeout_seconds" {
  description = "Tempo (s) em que uma mensagem fica invisível para outros consumidores após ser recebida (0 a 43200)."
  type        = number
  default     = 30
}

variable "message_retention_seconds" {
  description = "Tempo (s) que uma mensagem é retida na fila se não for deletada (60 a 1209600). Padrão: 4 dias."
  type        = number
  default     = 345600
}

variable "max_message_size" {
  description = "Tamanho máximo de uma mensagem, em bytes (1024 a 262144)."
  type        = number
  default     = 262144
}

variable "delay_seconds" {
  description = "Atraso (s) antes de uma mensagem ficar disponível para consumo (0 a 900)."
  type        = number
  default     = 0
}

variable "receive_wait_time_seconds" {
  description = "Tempo (s) de espera no long polling ao receber mensagens (0 a 20). Valores maiores reduzem chamadas vazias e custo."
  type        = number
  default     = 0
}

variable "create_dlq" {
  description = "Cria uma dead-letter queue e associa o redrive policy à fila principal."
  type        = bool
  default     = true
}

variable "max_receive_count" {
  description = "Número de tentativas de processamento antes de a mensagem ser movida para a DLQ."
  type        = number
  default     = 5
}

variable "dlq_message_retention_seconds" {
  description = "Tempo (s) de retenção das mensagens na DLQ. Costuma ser maior que o da fila principal. Padrão: 14 dias."
  type        = number
  default     = 1209600
}

variable "kms_master_key_id" {
  description = "ID, ARN ou alias de uma KMS key existente para criptografar as mensagens (SSE-KMS). Quando nulo, usa SSE-SQS (gerenciada, sem custo)."
  type        = string
  default     = null
}

variable "create_kms_key" {
  description = "Cria uma KMS key dedicada (SSE-KMS). Ignorado se kms_master_key_id for informado."
  type        = bool
  default     = false
}

variable "kms_key_deletion_window_in_days" {
  description = "Janela de espera, em dias, antes da exclusão definitiva da KMS key criada pelo módulo."
  type        = number
  default     = 30
}

variable "kms_data_key_reuse_period_seconds" {
  description = "Tempo (s) que o SQS pode reutilizar uma data key antes de chamar o KMS novamente (60 a 86400). Aplicável apenas com SSE-KMS."
  type        = number
  default     = 300
}

variable "policy" {
  description = "Documento JSON da access policy da fila. Use para permitir que serviços (SNS, EventBridge, S3) ou outras contas enviem mensagens. Quando nulo, nenhuma policy é anexada."
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags aplicadas a todos os recursos criados pelo módulo."
  type        = map(string)
  default     = {}
}
