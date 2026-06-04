variable "name" {
  description = "Nome do replication group e prefixo dos recursos."
  type        = string
}

variable "description" {
  description = "Descrição do replication group. Quando nula, é gerada a partir do name."
  type        = string
  default     = null
}

variable "engine" {
  description = "Engine do cache: redis ou valkey."
  type        = string
  default     = "redis"
}

variable "engine_version" {
  description = "Versão da engine (ex.: \"7.1\"). Quando nula, a AWS usa a versão padrão."
  type        = string
  default     = null
}

variable "node_type" {
  description = "Tipo de nó do cache (ex.: cache.t4g.micro, cache.r7g.large)."
  type        = string
  default     = "cache.t4g.micro"
}

variable "port" {
  description = "Porta de conexão do cache."
  type        = number
  default     = 6379
}

variable "cluster_mode_enabled" {
  description = "Habilita o modo cluster (sharding). Quando true, usa num_node_groups e replicas_per_node_group; caso contrário, usa num_cache_clusters."
  type        = bool
  default     = false
}

variable "num_cache_clusters" {
  description = "Número de nós (1 primário + réplicas) no modo não-cluster. Use >= 2 com automatic_failover para alta disponibilidade."
  type        = number
  default     = 1
}

variable "num_node_groups" {
  description = "Número de shards (node groups) no modo cluster."
  type        = number
  default     = 1
}

variable "replicas_per_node_group" {
  description = "Réplicas por shard no modo cluster."
  type        = number
  default     = 1
}

variable "automatic_failover_enabled" {
  description = "Habilita failover automático para uma réplica. Requer >= 2 nós. Forçado para true no modo cluster."
  type        = bool
  default     = false
}

variable "multi_az_enabled" {
  description = "Distribui as réplicas em múltiplas AZs. Requer automatic_failover_enabled."
  type        = bool
  default     = false
}

variable "vpc_id" {
  description = "ID da VPC onde o security group do cache será criado."
  type        = string
}

variable "subnet_ids" {
  description = "IDs das subnets (preferencialmente privadas) que compõem o subnet group do cache."
  type        = list(string)
}

variable "create_security_group" {
  description = "Cria um security group dedicado para o cache. Defina como false para usar apenas os security groups em vpc_security_group_ids."
  type        = bool
  default     = true
}

variable "vpc_security_group_ids" {
  description = "Security groups existentes a associar ao cache, somados ao criado pelo módulo (se houver)."
  type        = list(string)
  default     = []
}

variable "allowed_cidr_blocks" {
  description = "CIDRs autorizados a se conectar à porta do cache. Aplicado ao security group criado pelo módulo."
  type        = list(string)
  default     = []
}

variable "allowed_security_group_ids" {
  description = "Security groups autorizados a se conectar à porta do cache (ex.: SG dos nós do EKS). Aplicado ao security group criado pelo módulo."
  type        = list(string)
  default     = []
}

variable "at_rest_encryption_enabled" {
  description = "Habilita a criptografia dos dados em repouso."
  type        = bool
  default     = true
}

variable "transit_encryption_enabled" {
  description = "Habilita a criptografia em trânsito (TLS). Exige que os clientes se conectem via TLS."
  type        = bool
  default     = false
}

variable "auth_token" {
  description = "Senha do Redis AUTH para autenticação. Requer transit_encryption_enabled. Quando nula, não há AUTH."
  type        = string
  default     = null
  sensitive   = true
}

variable "create_kms_key" {
  description = "Cria uma KMS key dedicada para a criptografia em repouso. Ignorado se kms_key_arn for informado ou at_rest_encryption_enabled for false."
  type        = bool
  default     = false
}

variable "kms_key_arn" {
  description = "ARN de uma KMS key existente para a criptografia em repouso. Quando nulo e create_kms_key for false, a AWS usa a key padrão do serviço."
  type        = string
  default     = null
}

variable "kms_key_deletion_window_in_days" {
  description = "Janela de espera, em dias, antes da exclusão definitiva da KMS key criada pelo módulo."
  type        = number
  default     = 30
}

variable "snapshot_retention_limit" {
  description = "Dias de retenção dos snapshots automáticos. 0 desabilita (adequado para uso como cache puro)."
  type        = number
  default     = 0
}

variable "snapshot_window" {
  description = "Janela diária para snapshots, em UTC (ex.: \"03:00-05:00\"). Quando nula, a AWS escolhe."
  type        = string
  default     = null
}

variable "maintenance_window" {
  description = "Janela semanal de manutenção, em UTC (ex.: \"sun:05:00-sun:07:00\"). Quando nula, a AWS escolhe."
  type        = string
  default     = null
}

variable "apply_immediately" {
  description = "Aplica modificações imediatamente em vez de aguardar a janela de manutenção."
  type        = bool
  default     = false
}

variable "auto_minor_version_upgrade" {
  description = "Aplica automaticamente upgrades de versão minor."
  type        = bool
  default     = true
}

variable "create_parameter_group" {
  description = "Cria um parameter group dedicado para o cache."
  type        = bool
  default     = false
}

variable "parameter_group_family" {
  description = "Família do parameter group (ex.: \"redis7\", \"valkey7\"). Obrigatório quando create_parameter_group for true."
  type        = string
  default     = null
}

variable "parameters" {
  description = "Parâmetros aplicados ao parameter group criado pelo módulo."
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

variable "parameter_group_name" {
  description = "Nome de um parameter group existente. Usado quando create_parameter_group for false. Quando nulo, a AWS usa o default da engine."
  type        = string
  default     = null
}

variable "log_delivery_configuration" {
  description = "Configurações de entrega de logs (slow-log, engine-log) para CloudWatch Logs ou Kinesis Firehose. O destino deve existir."
  type = list(object({
    destination      = string
    destination_type = string
    log_format       = string
    log_type         = string
  }))
  default = []
}

variable "tags" {
  description = "Tags aplicadas a todos os recursos criados pelo módulo."
  type        = map(string)
  default     = {}
}
