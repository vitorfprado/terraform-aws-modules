# Módulo Terraform – RDS

Provisiona uma instância de banco de dados relacional gerenciada (Amazon RDS), com subnet group, security group dedicado, criptografia via KMS, gerenciamento de senha pelo Secrets Manager, Enhanced Monitoring e parameter group opcional.

Como os demais módulos do repositório, é independente: recebe a rede (`vpc_id` e `subnet_ids`) como entrada e não a cria. Para múltiplos bancos, chame o módulo várias vezes no consumer.

## Recursos criados

- `aws_db_instance` – a instância RDS
- `aws_db_subnet_group` – grupo de subnets onde a instância é provisionada
- `aws_security_group` + regras de ingress/egress – controle de acesso (opcional)
- `aws_kms_key` / `aws_kms_alias` – criptografia do armazenamento (opcional)
- `aws_iam_role` – role do Enhanced Monitoring (opcional)
- `aws_db_parameter_group` – ajustes de parâmetros da engine (opcional)

## Uso

```hcl
module "rds_app" {
  source = "github.com/vitorfprado/terraform-aws-modules//rds?ref=main"

  name           = "app"
  engine         = "postgres"
  engine_version = "16"
  instance_class = "db.t3.micro"

  allocated_storage = 20
  db_name           = "appdb"
  username          = "appuser"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids

  allowed_security_group_ids = [module.eks.cluster_security_group_id]

  tags = {
    Environment = "producao"
  }
}
```

Para subir mais de um banco, repita a chamada com outro `name`:

```hcl
module "rds_app"       { source = "...//rds?ref=main"  name = "app"       ... }
module "rds_analytics" { source = "...//rds?ref=main"  name = "analytics" ... }
```

Um exemplo completo e copiável (VPC + RDS) está em [`example/`](./example).

## Senha do banco

Por padrão (`manage_master_user_password = true`), a senha do usuário master é gerada e rotacionada pelo AWS Secrets Manager — ela **nunca** aparece no state do Terraform. O ARN do secret é exposto no output `master_user_secret_arn`. Para informar uma senha própria, defina `manage_master_user_password = false` e passe `password`.

## Requisitos

| Nome      | Versão   |
|-----------|----------|
| terraform | >= 1.5   |
| aws       | >= 5.40  |

## Variáveis de entrada

| Nome | Descrição | Tipo | Padrão | Obrigatória |
|------|-----------|------|--------|:-----------:|
| `name` | Identificador da instância e prefixo dos recursos. | `string` | — | sim |
| `vpc_id` | VPC onde o security group é criado. | `string` | — | sim |
| `subnet_ids` | Subnets do subnet group (recomenda-se privadas). | `list(string)` | — | sim |
| `engine` | Engine do banco. | `string` | `"postgres"` | não |
| `engine_version` | Versão da engine (null = padrão da AWS). | `string` | `null` | não |
| `instance_class` | Classe de instância. | `string` | `"db.t3.micro"` | não |
| `allocated_storage` | Armazenamento inicial (GB). | `number` | `20` | não |
| `max_allocated_storage` | Limite do storage autoscaling (GB; 0 desabilita). | `number` | `0` | não |
| `storage_type` | Tipo do volume. | `string` | `"gp3"` | não |
| `storage_encrypted` | Criptografia em repouso. | `bool` | `true` | não |
| `create_kms_key` | Cria KMS key dedicada. | `bool` | `true` | não |
| `kms_key_arn` | KMS key existente. | `string` | `null` | não |
| `kms_key_deletion_window_in_days` | Janela de exclusão da KMS key. | `number` | `30` | não |
| `db_name` | Banco inicial (null = nenhum). | `string` | `null` | não |
| `username` | Usuário master. | `string` | `"admin"` | não |
| `manage_master_user_password` | Senha gerenciada pelo Secrets Manager. | `bool` | `true` | não |
| `password` | Senha (se não usar Secrets Manager). | `string` | `null` | não |
| `port` | Porta (null = padrão da engine). | `number` | `null` | não |
| `multi_az` | Provisiona em Multi-AZ. | `bool` | `false` | não |
| `publicly_accessible` | Endereço público. | `bool` | `false` | não |
| `create_security_group` | Cria SG dedicado. | `bool` | `true` | não |
| `vpc_security_group_ids` | SGs existentes adicionais. | `list(string)` | `[]` | não |
| `allowed_cidr_blocks` | CIDRs com acesso à porta do banco. | `list(string)` | `[]` | não |
| `allowed_security_group_ids` | SGs com acesso à porta do banco. | `list(string)` | `[]` | não |
| `backup_retention_period` | Retenção de backups (dias; 0 desabilita). | `number` | `7` | não |
| `backup_window` | Janela de backup (UTC). | `string` | `null` | não |
| `maintenance_window` | Janela de manutenção (UTC). | `string` | `null` | não |
| `auto_minor_version_upgrade` | Upgrade automático de minor. | `bool` | `true` | não |
| `copy_tags_to_snapshot` | Copia tags para snapshots. | `bool` | `true` | não |
| `deletion_protection` | Proteção contra exclusão. | `bool` | `true` | não |
| `skip_final_snapshot` | Pula snapshot final no destroy. | `bool` | `false` | não |
| `final_snapshot_identifier` | Nome do snapshot final. | `string` | `null` | não |
| `apply_immediately` | Aplica mudanças imediatamente. | `bool` | `false` | não |
| `monitoring_interval` | Intervalo do Enhanced Monitoring (s; 0 desabilita). | `number` | `0` | não |
| `create_monitoring_role` | Cria role do Enhanced Monitoring. | `bool` | `true` | não |
| `monitoring_role_arn` | Role existente de monitoring. | `string` | `null` | não |
| `performance_insights_enabled` | Habilita Performance Insights. | `bool` | `false` | não |
| `enabled_cloudwatch_logs_exports` | Logs exportados ao CloudWatch. | `list(string)` | `[]` | não |
| `create_parameter_group` | Cria parameter group dedicado. | `bool` | `false` | não |
| `parameter_group_family` | Família do parameter group. | `string` | `null` | não |
| `parameters` | Parâmetros da engine. | `list(object)` | `[]` | não |
| `parameter_group_name` | Parameter group existente. | `string` | `null` | não |
| `tags` | Tags aplicadas a todos os recursos. | `map(string)` | `{}` | não |

## Outputs

| Nome | Descrição |
|------|-----------|
| `db_instance_id` | Identificador da instância. |
| `db_instance_arn` | ARN da instância. |
| `db_instance_endpoint` | Endpoint `host:porta`. |
| `db_instance_address` | Hostname (sem porta). |
| `db_instance_port` | Porta de conexão. |
| `db_instance_name` | Nome do banco inicial. |
| `db_instance_username` | Usuário master. |
| `master_user_secret_arn` | ARN do secret da senha (Secrets Manager). |
| `db_subnet_group_name` | Nome do subnet group. |
| `security_group_id` | ID do security group criado. |
| `kms_key_arn` | ARN da KMS key do armazenamento. |
| `monitoring_role_arn` | ARN da role do Enhanced Monitoring. |
| `parameter_group_name` | Parameter group em uso. |

## Liberando acesso a partir do EKS

O caso mais comum é permitir que pods do cluster acessem o banco. Passe o security group dos nós/cluster em `allowed_security_group_ids`:

```hcl
module "rds_app" {
  source = "github.com/vitorfprado/terraform-aws-modules//rds?ref=main"
  # ...
  allowed_security_group_ids = [module.eks.cluster_security_group_id]
}
```

Isso cria uma regra de ingress liberando a porta do banco apenas para o tráfego originado naquele security group — sem expor o banco a CIDRs amplos.
