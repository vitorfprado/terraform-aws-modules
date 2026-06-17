variable "name" {
  description = "Nome da instância e prefixo dos recursos."
  type        = string
}

variable "ami_id" {
  description = "ID da AMI. Quando nulo, usa a Amazon Linux 2023 mais recente da arquitetura informada em ami_architecture."
  type        = string
  default     = null
}

variable "ami_architecture" {
  description = "Arquitetura usada no lookup automático da Amazon Linux 2023: x86_64 ou arm64. Ignorado quando ami_id é informado."
  type        = string
  default     = "x86_64"
}

variable "instance_type" {
  description = "Tipo da instância EC2 (ex.: t3.micro, m7g.large)."
  type        = string
  default     = "t3.micro"
}

variable "vpc_id" {
  description = "ID da VPC onde o security group será criado."
  type        = string
}

variable "subnet_id" {
  description = "ID da subnet onde a instância será lançada."
  type        = string
}

variable "key_name" {
  description = "Nome do key pair para acesso SSH. Quando nulo, nenhuma chave é associada (use SSM Session Manager)."
  type        = string
  default     = null
}

variable "user_data" {
  description = "Script de inicialização (cloud-init) da instância. O provider faz o base64 automaticamente."
  type        = string
  default     = null
}

variable "user_data_replace_on_change" {
  description = "Recria a instância quando o user_data muda, em vez de apenas atualizar o atributo."
  type        = bool
  default     = false
}

variable "associate_public_ip_address" {
  description = "Atribui um IP público à instância. Mantenha false em subnets privadas."
  type        = bool
  default     = false
}

variable "create_eip" {
  description = "Cria e associa um Elastic IP à instância."
  type        = bool
  default     = false
}

variable "monitoring" {
  description = "Habilita o detailed monitoring (métricas a cada 1 minuto)."
  type        = bool
  default     = false
}

variable "metadata_http_tokens" {
  description = "Exigência de token no Instance Metadata Service: \"required\" força IMDSv2 (recomendado), \"optional\" permite IMDSv1."
  type        = string
  default     = "required"
}

variable "metadata_http_put_response_hop_limit" {
  description = "Limite de saltos de rede para respostas do metadata service. Use 2 quando a instância roda containers que precisam do metadata."
  type        = number
  default     = 1
}

variable "create_security_group" {
  description = "Cria um security group dedicado para a instância. Defina como false para usar apenas os security groups em vpc_security_group_ids."
  type        = bool
  default     = true
}

variable "vpc_security_group_ids" {
  description = "Security groups existentes a associar à instância, somados ao criado pelo módulo (se houver)."
  type        = list(string)
  default     = []
}

variable "ingress_rules" {
  description = "Regras de entrada do security group criado pelo módulo. Informe cidr_ipv4 OU referenced_security_group_id por regra."
  type = list(object({
    description                  = optional(string)
    from_port                    = number
    to_port                      = number
    ip_protocol                  = optional(string, "tcp")
    cidr_ipv4                    = optional(string)
    referenced_security_group_id = optional(string)
  }))
  default = []
}

variable "create_iam_instance_profile" {
  description = "Cria uma IAM role e instance profile para a instância."
  type        = bool
  default     = false
}

variable "iam_role_policy_arns" {
  description = "Mapa de ARNs de políticas IAM a anexar à role criada. A chave é um identificador livre (ex.: { ssm = \"arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore\" })."
  type        = map(string)
  default     = {}
}

variable "iam_instance_profile" {
  description = "Nome de um instance profile existente. Usado quando create_iam_instance_profile for false."
  type        = string
  default     = null
}

variable "root_volume_size" {
  description = "Tamanho do volume raiz, em GB."
  type        = number
  default     = 20
}

variable "root_volume_type" {
  description = "Tipo do volume raiz (gp3, gp2, io1, io2)."
  type        = string
  default     = "gp3"
}

variable "root_volume_encrypted" {
  description = "Criptografa o volume raiz."
  type        = bool
  default     = true
}

variable "ebs_volumes" {
  description = "Volumes EBS adicionais anexados à instância (na mesma AZ)."
  type = list(object({
    device_name = string
    size        = number
    type        = optional(string, "gp3")
    iops        = optional(number)
    throughput  = optional(number)
    encrypted   = optional(bool, true)
  }))
  default = []
}

variable "create_kms_key" {
  description = "Cria uma KMS key dedicada para criptografar os volumes. Ignorado se kms_key_arn for informado ou nenhum volume for criptografado."
  type        = bool
  default     = false
}

variable "kms_key_arn" {
  description = "ARN de uma KMS key existente para criptografar os volumes. Quando nulo e create_kms_key for false, a AWS usa a key padrão aws/ebs."
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
