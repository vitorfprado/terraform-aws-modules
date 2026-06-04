# Módulo Terraform – ElastiCache (Redis/Valkey)

Provisiona um cluster ElastiCache para Redis ou Valkey usando `aws_elasticache_replication_group`, com subnet group, security group dedicado, criptografia em repouso/trânsito, parameter group opcional e suporte aos modos não-cluster e cluster (sharding).

Como o RDS, é um recurso de VPC: recebe `vpc_id` e `subnet_ids` como entrada e não cria a rede. Para múltiplos caches, chame o módulo várias vezes no consumer.

> Este módulo cobre Redis/Valkey via replication group (o caminho recomendado pela AWS). Não cobre Memcached, que usa um recurso diferente (`aws_elasticache_cluster`).

## Recursos criados

- `aws_elasticache_replication_group` – o cluster Redis/Valkey
- `aws_elasticache_subnet_group` – subnets onde os nós são provisionados
- `aws_security_group` + regras – controle de acesso (opcional)
- `aws_elasticache_parameter_group` – ajustes da engine (opcional)
- `aws_kms_key` / `aws_kms_alias` – criptografia em repouso com key dedicada (opcional)

## Uso

```hcl
module "redis" {
  source = "github.com/vitorfprado/terraform-aws-modules//elasticache?ref=main"

  name           = "app-cache"
  engine         = "redis"
  engine_version = "7.1"
  node_type      = "cache.t4g.micro"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids

  allowed_security_group_ids = [module.eks.cluster_security_group_id]

  tags = {
    Environment = "producao"
  }
}
```

Cluster com alta disponibilidade (não-cluster, 1 primário + 1 réplica, failover):

```hcl
module "redis_ha" {
  source = "github.com/vitorfprado/terraform-aws-modules//elasticache?ref=main"

  name      = "sessions"
  node_type = "cache.r7g.large"

  num_cache_clusters         = 2
  automatic_failover_enabled = true
  multi_az_enabled           = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids
}
```

Um exemplo completo e copiável (VPC + Redis) está em [`example/`](./example).

## Topologia: não-cluster vs cluster

- **Não-cluster** (`cluster_mode_enabled = false`, padrão) — um único shard com 1 primário e N réplicas (`num_cache_clusters`). Use o `primary_endpoint_address` para escrita e o `reader_endpoint_address` para leitura.
- **Cluster** (`cluster_mode_enabled = true`) — dados particionados em `num_node_groups` shards, cada um com `replicas_per_node_group` réplicas. O cliente usa o `configuration_endpoint_address`. O failover automático é sempre habilitado neste modo.

Para alta disponibilidade no modo não-cluster, defina `num_cache_clusters >= 2`, `automatic_failover_enabled = true` e `multi_az_enabled = true`.

## Criptografia

- **Em repouso** (`at_rest_encryption_enabled`, padrão `true`) — transparente, sem impacto no cliente. Usa a key padrão do serviço, a menos que `create_kms_key = true` ou `kms_key_arn` seja informado.
- **Em trânsito** (`transit_encryption_enabled`, padrão `false`) — TLS. Exige que os clientes se conectem via TLS; por isso vem desabilitado para não quebrar clientes não configurados. Habilite em produção.
- **Redis AUTH** (`auth_token`) — senha de autenticação. Requer criptografia em trânsito.

## Requisitos

| Nome      | Versão   |
|-----------|----------|
| terraform | >= 1.5   |
| aws       | >= 5.40  |

## Variáveis de entrada

| Nome | Descrição | Tipo | Padrão | Obrigatória |
|------|-----------|------|--------|:-----------:|
| `name` | Nome do replication group e prefixo. | `string` | — | sim |
| `vpc_id` | VPC onde o SG é criado. | `string` | — | sim |
| `subnet_ids` | Subnets do subnet group. | `list(string)` | — | sim |
| `description` | Descrição (null = gerada do name). | `string` | `null` | não |
| `engine` | redis ou valkey. | `string` | `"redis"` | não |
| `engine_version` | Versão da engine. | `string` | `null` | não |
| `node_type` | Tipo de nó. | `string` | `"cache.t4g.micro"` | não |
| `port` | Porta de conexão. | `number` | `6379` | não |
| `cluster_mode_enabled` | Habilita sharding. | `bool` | `false` | não |
| `num_cache_clusters` | Nós no modo não-cluster. | `number` | `1` | não |
| `num_node_groups` | Shards no modo cluster. | `number` | `1` | não |
| `replicas_per_node_group` | Réplicas por shard (cluster). | `number` | `1` | não |
| `automatic_failover_enabled` | Failover automático. | `bool` | `false` | não |
| `multi_az_enabled` | Réplicas em múltiplas AZs. | `bool` | `false` | não |
| `create_security_group` | Cria SG dedicado. | `bool` | `true` | não |
| `vpc_security_group_ids` | SGs existentes adicionais. | `list(string)` | `[]` | não |
| `allowed_cidr_blocks` | CIDRs com acesso ao cache. | `list(string)` | `[]` | não |
| `allowed_security_group_ids` | SGs com acesso ao cache. | `list(string)` | `[]` | não |
| `at_rest_encryption_enabled` | Criptografia em repouso. | `bool` | `true` | não |
| `transit_encryption_enabled` | Criptografia em trânsito (TLS). | `bool` | `false` | não |
| `auth_token` | Senha do Redis AUTH. | `string` | `null` | não |
| `create_kms_key` | Cria KMS key dedicada. | `bool` | `false` | não |
| `kms_key_arn` | KMS key existente. | `string` | `null` | não |
| `kms_key_deletion_window_in_days` | Janela de exclusão da KMS key. | `number` | `30` | não |
| `snapshot_retention_limit` | Dias de retenção de snapshots (0 desabilita). | `number` | `0` | não |
| `snapshot_window` | Janela de snapshots (UTC). | `string` | `null` | não |
| `maintenance_window` | Janela de manutenção (UTC). | `string` | `null` | não |
| `apply_immediately` | Aplica mudanças imediatamente. | `bool` | `false` | não |
| `auto_minor_version_upgrade` | Upgrade automático de minor. | `bool` | `true` | não |
| `create_parameter_group` | Cria parameter group. | `bool` | `false` | não |
| `parameter_group_family` | Família do parameter group. | `string` | `null` | não |
| `parameters` | Parâmetros da engine. | `list(object)` | `[]` | não |
| `parameter_group_name` | Parameter group existente. | `string` | `null` | não |
| `log_delivery_configuration` | Entrega de logs (slow/engine). | `list(object)` | `[]` | não |
| `tags` | Tags aplicadas a todos os recursos. | `map(string)` | `{}` | não |

## Outputs

| Nome | Descrição |
|------|-----------|
| `replication_group_id` | ID do replication group. |
| `replication_group_arn` | ARN do replication group. |
| `primary_endpoint_address` | Endpoint de escrita (não-cluster). |
| `reader_endpoint_address` | Endpoint de leitura (não-cluster). |
| `configuration_endpoint_address` | Endpoint de configuração (cluster). |
| `port` | Porta de conexão. |
| `member_clusters` | Nós do replication group. |
| `security_group_id` | ID do security group criado. |
| `subnet_group_name` | Nome do subnet group. |
| `kms_key_arn` | ARN da KMS key dedicada, quando criada. |

## Liberando acesso a partir do EKS

Assim como no RDS, libere o cache para o security group dos nós/cluster:

```hcl
module "redis" {
  source = "github.com/vitorfprado/terraform-aws-modules//elasticache?ref=main"
  # ...
  allowed_security_group_ids = [module.eks.cluster_security_group_id]
}
```
