# Explicação detalhada — módulo ElastiCache

Este documento percorre cada arquivo do módulo explicando **o que o código faz e por quê foi escrito assim**.

O ElastiCache volta a ser um recurso **dentro da VPC** (como o RDS), diferente do DynamoDB e do SQS. Por isso o módulo tem subnet group e security group, e recebe `vpc_id`/`subnet_ids` de fora.

## Por que `aws_elasticache_replication_group`

O ElastiCache tem dois recursos no provider:

- `aws_elasticache_cluster` — usado para Memcached e, historicamente, Redis single-node.
- `aws_elasticache_replication_group` — usado para Redis/Valkey com replicação, failover, multi-AZ e modo cluster.

Este módulo usa o **replication group** porque é o caminho recomendado pela AWS para Redis/Valkey: cobre desde um único nó até clusters com sharding, tudo no mesmo recurso. Memcached fica de fora deliberadamente — é um caso de uso diferente, com recurso e semântica próprios, e misturar os dois no mesmo módulo geraria muita lógica condicional.

---

## `variables.tf`

### Topologia — o ponto mais importante

```hcl
variable "cluster_mode_enabled" { default = false }
variable "num_cache_clusters"   { default = 1 }      # não-cluster
variable "num_node_groups"      { default = 1 }      # cluster
variable "replicas_per_node_group" { default = 1 }   # cluster
```

O replication group opera em dois modos mutuamente exclusivos:

- **Não-cluster** — um único shard. `num_cache_clusters` define o total de nós (1 primário + réplicas). Todos os dados ficam em um nó primário; réplicas são cópias para leitura e failover.
- **Cluster (sharding)** — dados particionados em `num_node_groups` shards, cada um com `replicas_per_node_group` réplicas. Escala horizontalmente além do que um único nó comporta.

A variável `cluster_mode_enabled` escolhe entre os dois, e o `main.tf` envia apenas os argumentos do modo selecionado.

### Encriptação em trânsito desabilitada por padrão

```hcl
variable "transit_encryption_enabled" { default = false }
```

Diferente da criptografia em repouso (transparente), a criptografia em trânsito (TLS) **muda o comportamento do cliente**: a aplicação precisa conectar via TLS. Habilitá-la por padrão quebraria clientes não configurados. Por isso o default é `false`, com recomendação explícita de habilitar em produção. Já a criptografia em repouso é `true` por padrão, pois não tem impacto no cliente.

---

## `main.tf` — locals, subnet group e replication group

### locals

```hcl
locals {
  create_kms_key_resource = var.at_rest_encryption_enabled && var.create_kms_key && var.kms_key_arn == null
  kms_key_arn             = var.kms_key_arn != null ? var.kms_key_arn : (local.create_kms_key_resource ? aws_kms_key.elasticache[0].arn : null)
  security_group_ids      = var.create_security_group ? concat([aws_security_group.elasticache[0].id], var.vpc_security_group_ids) : var.vpc_security_group_ids
  parameter_group_name    = var.create_parameter_group ? aws_elasticache_parameter_group.elasticache[0].name : var.parameter_group_name
}
```

A mesma estrutura de locals dos módulos RDS/SQS: resolução condicional de KMS, combinação dos security groups (o criado pelo módulo + os passados pelo usuário) e escolha do parameter group (criado vs. existente vs. default da engine).

### Topologia condicional

```hcl
num_cache_clusters      = var.cluster_mode_enabled ? null : var.num_cache_clusters
num_node_groups         = var.cluster_mode_enabled ? var.num_node_groups : null
replicas_per_node_group = var.cluster_mode_enabled ? var.replicas_per_node_group : null

automatic_failover_enabled = var.cluster_mode_enabled ? true : var.automatic_failover_enabled
```

Aqui está a tradução do modo escolhido para os argumentos do recurso. No modo cluster, `num_cache_clusters` precisa ser omitido (`null`) e os argumentos de shard preenchidos — e vice-versa. Enviar os dois conjuntos juntos causaria erro.

O `automatic_failover_enabled` é **forçado para `true`** no modo cluster, porque a AWS o exige nesse modo. No modo não-cluster ele respeita a variável (e só funciona com 2+ nós).

### Criptografia condicional

```hcl
at_rest_encryption_enabled = var.at_rest_encryption_enabled
kms_key_id                 = var.at_rest_encryption_enabled ? local.kms_key_arn : null
transit_encryption_enabled = var.transit_encryption_enabled
auth_token                 = var.transit_encryption_enabled ? var.auth_token : null
```

O `kms_key_id` só é enviado quando há criptografia em repouso; quando `local.kms_key_arn` é `null` (criptografia ligada mas sem CMK), a AWS usa a chave padrão do serviço. O `auth_token` (senha Redis AUTH) só é válido com criptografia em trânsito, então é anulado caso contrário — a própria AWS rejeita AUTH sem TLS.

### Log delivery como passthrough

```hcl
dynamic "log_delivery_configuration" {
  for_each = var.log_delivery_configuration
  content { ... }
}
```

A entrega de slow-log e engine-log é um bloco dinâmico opcional. O módulo repassa a configuração mas **não cria** o destino (log group do CloudWatch ou stream do Firehose) — isso é responsabilidade do consumidor, que informa o ARN/nome do destino já existente. Mantém o módulo focado sem assumir como você organiza seus logs.

---

## `security_group.tf`

Idêntico em estrutura ao do RDS: um SG dedicado (com `create_before_destroy`) e regras de ingress separadas via `aws_vpc_security_group_ingress_rule` — uma por CIDR e uma por security group de origem — liberando apenas a porta do cache. O motivo de usar regras como recursos separados (em vez de inline) é o mesmo: evitar *perpetual diffs*.

O caso mais comum é liberar o cache para o security group dos nós do EKS, via `allowed_security_group_ids` — sem expor o Redis a faixas de IP amplas.

---

## `parameter_group.tf`

```hcl
resource "aws_elasticache_parameter_group" "elasticache" {
  count  = var.create_parameter_group ? 1 : 0
  name   = "${var.name}-params"
  family = var.parameter_group_family
  ...
}
```

Opcional, para ajustar parâmetros da engine (ex.: `maxmemory-policy`, `timeout`). Diferente do RDS, o `aws_elasticache_parameter_group` **não aceita `name_prefix`** — apenas `name` — por isso o nome é fixo (`<name>-params`). A família (ex.: `redis7`, `valkey7`) precisa casar com a engine e a versão.

---

## `kms.tf`

Mesma estrutura dos demais: key dedicada com rotação automática, criada só quando a criptografia em repouso está ligada **e** o usuário pede uma key própria. Caso contrário, o ElastiCache usa a chave gerenciada padrão do serviço — os dados continuam criptografados.

---

## Endpoints: qual usar

O replication group expõe endpoints diferentes conforme o modo, e isso costuma confundir:

- **Não-cluster:** use `primary_endpoint_address` para escrita e `reader_endpoint_address` para leitura (distribui entre as réplicas). O `configuration_endpoint_address` fica vazio.
- **Cluster:** use `configuration_endpoint_address` — o cliente cluster-aware descobre os shards a partir dele. Os endpoints primário/reader ficam vazios.

O módulo expõe os três como output; o consumidor usa o adequado ao modo escolhido.

---

## Ordem de criação dos recursos

```
aws_kms_key.elasticache ─► aws_kms_alias.elasticache       (se at-rest + create_kms_key)
        │
aws_security_group.elasticache ─► ingress/egress rules
        │
aws_elasticache_subnet_group.main
        │
aws_elasticache_parameter_group.elasticache                (se create_parameter_group)
        │
        └──────► aws_elasticache_replication_group.main
```

O replication group depende do subnet group (onde rodar), do security group (quem acessa), da KMS key (criptografia) e do parameter group. O Terraform infere tudo pelas referências de atributo, sem `depends_on` explícito.
