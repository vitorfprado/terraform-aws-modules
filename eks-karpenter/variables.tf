variable "cluster_name" {
  description = "Nome do cluster EKS que o Karpenter vai provisionar. Entra na policy do controller e nos nomes padrão dos recursos."
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN do OIDC provider do cluster (output oidc_provider_arn do módulo eks). Necessário para a IRSA do controller."
  type        = string
}

variable "oidc_provider_url" {
  description = "URL do issuer OIDC do cluster, com ou sem o prefixo https:// (output oidc_provider_url do módulo eks)."
  type        = string
}

variable "region" {
  description = "Região AWS do cluster, usada na policy do controller. Quando nulo, é resolvida pelo provider."
  type        = string
  default     = null
}

# ── Vínculo com o service account do controller ───────────────────────────────

variable "namespace" {
  description = "Namespace onde o controller do Karpenter roda. O padrão recomendado a partir do v1 é kube-system."
  type        = string
  default     = "kube-system"
}

variable "service_account_name" {
  description = "Nome do service account do controller do Karpenter. Precisa bater com o serviceAccount.name usado na instalação do chart."
  type        = string
  default     = "karpenter"
}

# ── Nomes determinísticos ─────────────────────────────────────────────────────
# Nomes previsíveis (e não name_prefix) para que os manifests/values do cluster
# possam referenciá-los sem resolver output de Terraform em tempo de render.

variable "controller_role_name" {
  description = "Nome da IAM role (IRSA) do controller. Quando nulo, usa <cluster_name>-karpenter-controller."
  type        = string
  default     = null
}

variable "node_role_name" {
  description = "Nome da IAM role dos nós provisionados pelo Karpenter. Quando nulo, usa <cluster_name>-karpenter-node. É o valor que vai em spec.role do EC2NodeClass."
  type        = string
  default     = null
}

variable "interruption_queue_name" {
  description = "Nome da fila SQS de interrupção. Quando nulo, usa <cluster_name>-karpenter. É o valor que vai em settings.interruptionQueue do chart."
  type        = string
  default     = null
}

# ── Role dos nós ──────────────────────────────────────────────────────────────

variable "node_role_additional_policy_arns" {
  description = "Managed policies extras para a role dos nós, além das quatro obrigatórias. Key = rótulo estático (conhecido no plan); value = ARN."
  type        = map(string)
  default     = {}
}

variable "create_node_access_entry" {
  description = "Cria o aws_eks_access_entry do tipo EC2_LINUX para a role dos nós. Desative apenas se o access entry já for gerenciado fora do módulo."
  type        = bool
  default     = true
}

variable "node_role_max_session_duration" {
  description = "Duração máxima da sessão da role dos nós, em segundos (3600–43200)."
  type        = number
  default     = 3600
}

# ── Fila de interrupção ───────────────────────────────────────────────────────

variable "interruption_queue_retention_seconds" {
  description = "Retenção das mensagens na fila de interrupção. O padrão de 300s é o recomendado pelo Karpenter: eventos mais antigos que isso já não são acionáveis."
  type        = number
  default     = 300
}

# ── SSM Parameter Store ───────────────────────────────────────────────────────

variable "create_ssm_parameters" {
  description = "Publica no Parameter Store os valores que a camada de manifests precisa (ARN da role do controller, nome da role dos nós e nome da fila), para serem lidos sem acessar o tfstate."
  type        = bool
  default     = false
}

variable "ssm_parameter_prefix" {
  description = "Prefixo dos parâmetros SSM. Quando nulo, usa /karpenter/<cluster_name>."
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags aplicadas a todos os recursos criados pelo módulo."
  type        = map(string)
  default     = {}
}
