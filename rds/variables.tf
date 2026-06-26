variable "name" {
  description = "Nome/identificador da instância RDS. Usado como prefixo na nomeação dos recursos."
  type        = string
}

variable "engine" {
  description = "Engine do banco de dados (postgres, mysql, mariadb, etc.)."
  type        = string
  default     = "postgres"
}

variable "engine_version" {
  description = "Versão da engine. Quando nulo, a AWS usa a versão padrão da engine. Pode ser uma versão maior (ex.: \"16\") para a AWS escolher a minor."
  type        = string
  default     = null
}

variable "instance_class" {
  description = "Classe de instância do RDS (ex.: db.t3.micro, db.r6g.large)."
  type        = string
  default     = "db.t3.micro"
}

variable "allocated_storage" {
  description = "Armazenamento inicial alocado, em GB."
  type        = number
  default     = 20
}

variable "max_allocated_storage" {
  description = "Limite máximo do storage autoscaling, em GB. Use 0 para desabilitar o autoscaling."
  type        = number
  default     = 0
}

variable "storage_type" {
  description = "Tipo do volume de armazenamento (gp3, gp2, io1, io2)."
  type        = string
  default     = "gp3"
}

variable "storage_encrypted" {
  description = "Habilita a criptografia do armazenamento em repouso."
  type        = bool
  default     = true
}

variable "create_kms_key" {
  description = "Cria uma KMS key dedicada para criptografar o armazenamento. Ignorado se kms_key_arn for informado ou storage_encrypted for false."
  type        = bool
  default     = true
}

variable "kms_key_arn" {
  description = "ARN de uma KMS key existente para criptografar o armazenamento. Quando nulo e create_kms_key for false, a AWS usa a key padrão aws/rds."
  type        = string
  default     = null
}

variable "kms_key_deletion_window_in_days" {
  description = "Janela de espera, em dias, antes da exclusão definitiva da KMS key criada pelo módulo."
  type        = number
  default     = 30
}

variable "db_name" {
  description = "Nome do banco de dados inicial criado na instância. Quando nulo, nenhum banco é criado automaticamente."
  type        = string
  default     = null
}

variable "username" {
  description = "Usuário master do banco de dados."
  type        = string
  default     = "admin"
}

variable "manage_master_user_password" {
  description = "Delega a geração e rotação da senha do usuário master ao AWS Secrets Manager. Recomendado: a senha nunca fica no state."
  type        = bool
  default     = true
}

variable "password" {
  description = "Senha do usuário master. Usada apenas quando manage_master_user_password for false."
  type        = string
  default     = null
  sensitive   = true
}

variable "port" {
  description = "Porta de conexão do banco. Quando nulo, usa a porta padrão da engine (postgres 5432, mysql/mariadb 3306)."
  type        = number
  default     = null
}

variable "vpc_id" {
  description = "ID da VPC onde o security group do banco será criado."
  type        = string
}

variable "subnet_ids" {
  description = "IDs das subnets (preferencialmente privadas) que compõem o subnet group do RDS."
  type        = list(string)
}

variable "multi_az" {
  description = "Provisiona a instância em modo Multi-AZ (réplica standby em outra AZ para alta disponibilidade)."
  type        = bool
  default     = false
}

variable "publicly_accessible" {
  description = "Atribui um endereço público à instância. Mantenha false para bancos em subnets privadas."
  type        = bool
  default     = false
}

variable "create_security_group" {
  description = "Cria um security group dedicado para o banco. Defina como false para usar apenas os security groups em vpc_security_group_ids."
  type        = bool
  default     = true
}

variable "security_group_name" {
  description = "Nome do security group criado para o RDS. Quando null, usa o padrão <name>-rds."
  type        = string
  default     = null
}

variable "vpc_security_group_ids" {
  description = "Security groups existentes a associar à instância, somados ao criado pelo módulo (se houver)."
  type        = list(string)
  default     = []
}

variable "allowed_cidr_blocks" {
  description = "CIDRs autorizados a se conectar à porta do banco. Aplicado ao security group criado pelo módulo."
  type        = list(string)
  default     = []
}

variable "allowed_security_group_ids" {
  description = "Security groups autorizados a se conectar à porta do banco (ex.: SG dos nós do EKS). Aplicado ao security group criado pelo módulo."
  type        = list(string)
  default     = []
}

variable "backup_retention_period" {
  description = "Período de retenção dos backups automáticos, em dias. Use 0 para desabilitar."
  type        = number
  default     = 7
}

variable "backup_window" {
  description = "Janela diária preferencial para backups, em UTC (ex.: \"03:00-04:00\"). Quando nulo, a AWS escolhe."
  type        = string
  default     = null
}

variable "maintenance_window" {
  description = "Janela semanal preferencial para manutenção, em UTC (ex.: \"Mon:04:00-Mon:05:00\"). Quando nulo, a AWS escolhe."
  type        = string
  default     = null
}

variable "auto_minor_version_upgrade" {
  description = "Aplica automaticamente upgrades de versão minor durante a janela de manutenção."
  type        = bool
  default     = true
}

variable "copy_tags_to_snapshot" {
  description = "Copia as tags da instância para os snapshots gerados."
  type        = bool
  default     = true
}

variable "deletion_protection" {
  description = "Impede a exclusão acidental da instância. Recomendado true em produção."
  type        = bool
  default     = true
}

variable "skip_final_snapshot" {
  description = "Pula o snapshot final ao destruir a instância. Mantenha false em produção para preservar os dados."
  type        = bool
  default     = false
}

variable "final_snapshot_identifier" {
  description = "Nome do snapshot final. Quando nulo, usa \"<name>-final-snapshot\". Ignorado se skip_final_snapshot for true."
  type        = string
  default     = null
}

variable "apply_immediately" {
  description = "Aplica modificações imediatamente em vez de aguardar a janela de manutenção. Pode causar downtime."
  type        = bool
  default     = false
}

variable "monitoring_interval" {
  description = "Intervalo, em segundos, da coleta de métricas do Enhanced Monitoring (0, 1, 5, 10, 15, 30 ou 60). 0 desabilita."
  type        = number
  default     = 0
}

variable "create_monitoring_role" {
  description = "Cria a IAM role do Enhanced Monitoring. Ignorado quando monitoring_interval for 0."
  type        = bool
  default     = true
}

variable "monitoring_role_arn" {
  description = "ARN de uma IAM role existente para o Enhanced Monitoring. Usado quando create_monitoring_role for false."
  type        = string
  default     = null
}

variable "performance_insights_enabled" {
  description = "Habilita o Performance Insights na instância."
  type        = bool
  default     = false
}

variable "enabled_cloudwatch_logs_exports" {
  description = "Tipos de log exportados para o CloudWatch (depende da engine; ex.: [\"postgresql\"] ou [\"error\", \"general\", \"slowquery\"])."
  type        = list(string)
  default     = []
}

variable "create_parameter_group" {
  description = "Cria um parameter group dedicado para a instância."
  type        = bool
  default     = false
}

variable "parameter_group_family" {
  description = "Família do parameter group (ex.: \"postgres16\", \"mysql8.0\"). Obrigatório quando create_parameter_group for true."
  type        = string
  default     = null
}

variable "parameters" {
  description = "Parâmetros aplicados ao parameter group criado pelo módulo."
  type = list(object({
    name         = string
    value        = string
    apply_method = optional(string, "immediate")
  }))
  default = []
}

variable "parameter_group_name" {
  description = "Nome de um parameter group existente. Usado quando create_parameter_group for false."
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags aplicadas a todos os recursos criados pelo módulo."
  type        = map(string)
  default     = {}
}
