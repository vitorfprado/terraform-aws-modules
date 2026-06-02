variable "cluster_name" {
  description = "Nome do cluster EKS. Usado como prefixo na nomeação dos recursos gerenciados pelo módulo."
  type        = string
}

variable "cluster_version" {
  description = "Versão do Kubernetes do control plane (ex.: \"1.32\")."
  type        = string
  default     = "1.32"
}

variable "vpc_id" {
  description = "ID da VPC onde o cluster e os node groups serão provisionados."
  type        = string
}

variable "subnet_ids" {
  description = "IDs das subnets usadas pelos node groups e, por padrão, pelas ENIs do control plane. Recomenda-se subnets privadas."
  type        = list(string)
}

variable "control_plane_subnet_ids" {
  description = "IDs das subnets dedicadas às ENIs do control plane. Quando vazio, reutiliza subnet_ids."
  type        = list(string)
  default     = []
}

variable "endpoint_private_access" {
  description = "Habilita o acesso privado ao endpoint da API do Kubernetes (a partir da VPC)."
  type        = bool
  default     = true
}

variable "endpoint_public_access" {
  description = "Habilita o acesso público ao endpoint da API do Kubernetes."
  type        = bool
  default     = false
}

variable "public_access_cidrs" {
  description = "Lista de CIDRs autorizados a acessar o endpoint público. Ignorado quando endpoint_public_access é false."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "additional_security_group_ids" {
  description = "Security groups adicionais a serem associados ao control plane do cluster."
  type        = list(string)
  default     = []
}

variable "cluster_enabled_log_types" {
  description = "Tipos de log do control plane enviados ao CloudWatch (api, audit, authenticator, controllerManager, scheduler)."
  type        = list(string)
  default     = ["api", "audit", "authenticator"]
}

variable "cloudwatch_log_retention_in_days" {
  description = "Período de retenção, em dias, dos logs do control plane no CloudWatch."
  type        = number
  default     = 90
}

variable "cloudwatch_log_kms_key_id" {
  description = "ARN da KMS key usada para criptografar o log group do CloudWatch. Quando nulo, a criptografia padrão é aplicada."
  type        = string
  default     = null
}

variable "authentication_mode" {
  description = "Modo de autenticação do cluster: API, API_AND_CONFIG_MAP ou CONFIG_MAP."
  type        = string
  default     = "API_AND_CONFIG_MAP"

  validation {
    condition     = contains(["API", "API_AND_CONFIG_MAP", "CONFIG_MAP"], var.authentication_mode)
    error_message = "authentication_mode deve ser API, API_AND_CONFIG_MAP ou CONFIG_MAP."
  }
}

variable "bootstrap_cluster_creator_admin_permissions" {
  description = "Concede permissão de administrador do cluster ao principal IAM que cria o cluster."
  type        = bool
  default     = true
}

variable "create_cluster_iam_role" {
  description = "Cria a IAM role do control plane. Defina como false para informar uma role existente em cluster_iam_role_arn."
  type        = bool
  default     = true
}

variable "cluster_iam_role_arn" {
  description = "ARN de uma IAM role existente para o control plane. Obrigatório quando create_cluster_iam_role é false."
  type        = string
  default     = null
}

variable "create_node_iam_role" {
  description = "Cria a IAM role compartilhada pelos node groups gerenciados. Defina como false para informar uma role existente."
  type        = bool
  default     = true
}

variable "node_iam_role_arn" {
  description = "ARN de uma IAM role existente para os nodes. Obrigatório quando create_node_iam_role é false."
  type        = string
  default     = null
}

variable "node_iam_role_additional_policies" {
  description = "Mapa de ARNs de políticas IAM adicionais a anexar na role dos nodes. A chave é um identificador livre."
  type        = map(string)
  default     = {}
}

variable "enable_irsa" {
  description = "Cria o OIDC provider do cluster, habilitando IAM Roles for Service Accounts (IRSA)."
  type        = bool
  default     = true
}

variable "create_kms_key" {
  description = "Cria uma KMS key dedicada para criptografar os secrets do Kubernetes (envelope encryption)."
  type        = bool
  default     = true
}

variable "kms_key_arn" {
  description = "ARN de uma KMS key existente para criptografar os secrets. Usado quando create_kms_key é false."
  type        = string
  default     = null
}

variable "kms_key_deletion_window_in_days" {
  description = "Janela de espera, em dias, antes da exclusão definitiva da KMS key criada pelo módulo."
  type        = number
  default     = 30
}

variable "node_groups" {
  description = "Mapa de managed node groups. A chave é o sufixo do nome do node group e o valor define seu dimensionamento e configuração."
  type = map(object({
    instance_types             = optional(list(string), ["t3.medium"])
    capacity_type              = optional(string, "ON_DEMAND")
    ami_type                   = optional(string, "AL2023_x86_64_STANDARD")
    disk_size                  = optional(number, 20)
    desired_size               = optional(number, 2)
    min_size                   = optional(number, 1)
    max_size                   = optional(number, 3)
    subnet_ids                 = optional(list(string), [])
    labels                     = optional(map(string), {})
    max_unavailable            = optional(number)
    max_unavailable_percentage = optional(number)
    taints = optional(list(object({
      key    = string
      value  = optional(string)
      effect = string
    })), [])
    tags = optional(map(string), {})
  }))
  default = {}
}

variable "cluster_addons" {
  description = "Mapa de EKS add-ons gerenciados (ex.: coredns, kube-proxy, vpc-cni). A chave é o nome do add-on."
  type = map(object({
    version                     = optional(string)
    service_account_role_arn    = optional(string)
    configuration_values        = optional(string)
    preserve                    = optional(bool, true)
    resolve_conflicts_on_create = optional(string, "OVERWRITE")
    resolve_conflicts_on_update = optional(string, "OVERWRITE")
  }))
  default = {}
}

variable "access_entries" {
  description = "Mapa de access entries do EKS (substitui o aws-auth). Cada entrada associa um principal IAM a políticas de acesso."
  type = map(object({
    principal_arn     = string
    type              = optional(string, "STANDARD")
    kubernetes_groups = optional(list(string))
    policy_associations = optional(map(object({
      policy_arn = string
      scope_type = optional(string, "cluster")
      namespaces = optional(list(string))
    })), {})
  }))
  default = {}
}

variable "tags" {
  description = "Tags aplicadas a todos os recursos criados pelo módulo."
  type        = map(string)
  default     = {}
}
