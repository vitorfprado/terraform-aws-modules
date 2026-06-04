# Explicação detalhada — módulo RDS

Este documento percorre cada arquivo do módulo explicando **o que o código faz e por quê foi escrito assim**.

---

## `variables.tf`

### Identidade e engine

`name` é a única variável obrigatória junto com `vpc_id` e `subnet_ids`. Vira o `identifier` da instância e prefixo de todos os recursos auxiliares.

`engine` / `engine_version` / `instance_class` definem o motor (postgres por padrão), a versão e o tamanho da instância. `engine_version` com default `null` deixa a AWS escolher a versão padrão da engine; passar uma versão maior como `"16"` faz a AWS selecionar a minor mais recente daquela major.

### Armazenamento

`allocated_storage` é o disco inicial. `max_allocated_storage` ativa o storage autoscaling — quando maior que zero, a AWS expande o disco automaticamente até esse limite conforme o uso cresce. `storage_encrypted` (default `true`) liga a criptografia em repouso.

### Senha — a decisão de segurança central

```hcl
variable "manage_master_user_password" {
  type    = bool
  default = true
}
```

Por padrão, o módulo delega a senha ao AWS Secrets Manager. Isso é importante porque, na alternativa (`password` como variável), a senha acabaria **gravada em texto no state do Terraform** — qualquer pessoa com acesso ao state veria a senha. Com `manage_master_user_password = true`, a AWS gera e rotaciona a senha, e o Terraform nunca a vê.

### Rede e acesso

`vpc_id` e `subnet_ids` vêm de fora (do módulo VPC, por exemplo) — o módulo não cria rede. `allowed_cidr_blocks` e `allowed_security_group_ids` controlam quem pode conectar na porta do banco. A separação entre os dois permite liberar por faixa de IP **ou** por security group de origem (ex.: o SG dos nós do EKS), que é a forma mais segura.

---

## `main.tf` — locals, subnet group e instância

### locals

```hcl
locals {
  default_ports = { postgres = 5432, mysql = 3306, mariadb = 3306 }
  port          = var.port != null ? var.port : lookup(local.default_ports, var.engine, 5432)
  ...
}
```

**`port`** — o security group precisa de uma porta concreta para criar as regras de ingress, mas o usuário normalmente não quer informá-la. Este local resolve a porta padrão a partir da engine. Para engines fora do mapa (SQL Server, Oracle), o `lookup` cai no default 5432 e o usuário deve informar `port` explicitamente.

**`kms_key_arn`** — segue uma cadeia de prioridade: se o usuário passou uma key existente, usa ela; senão, se o módulo deve criar uma (`create_kms_key_resource`), usa a criada; senão, fica `null` (a AWS usa a key padrão `aws/rds`).

**`security_group_ids`** — combina o SG criado pelo módulo (quando habilitado) com quaisquer SGs adicionais passados pelo usuário, usando `concat`. Permite ter o SG gerenciado pelo módulo **e** SGs externos ao mesmo tempo.

**`monitoring_role_arn`** — só resolve uma role quando `monitoring_interval > 0`. Dentro disso, cria ou usa uma existente. Quando o monitoring está desligado, fica `null` e o argumento não é enviado à instância.

### Subnet group

```hcl
resource "aws_db_subnet_group" "rds" {
  name_prefix = "${var.name}-"
  subnet_ids  = var.subnet_ids
}
```

O subnet group diz ao RDS em quais subnets ele pode colocar a instância (e a standby, no caso Multi-AZ). Usa `name_prefix` em vez de `name` para que o Terraform consiga recriar o recurso sem conflito de nome durante substituições.

### Instância

```hcl
resource "aws_db_instance" "main" {
  ...
  max_allocated_storage = var.max_allocated_storage > 0 ? var.max_allocated_storage : null

  manage_master_user_password = var.manage_master_user_password ? true : null
  password                    = var.manage_master_user_password ? null : var.password

  kms_key_id = var.storage_encrypted ? local.kms_key_arn : null

  final_snapshot_identifier = var.skip_final_snapshot ? null : coalesce(var.final_snapshot_identifier, "${var.name}-final-snapshot")
}
```

Vários argumentos usam o padrão `condição ? valor : null`. No Terraform, passar `null` faz o argumento ser **omitido** (como se não tivesse sido escrito), deixando a AWS aplicar o comportamento padrão. Isso é usado para:

- **`max_allocated_storage`** — omitido quando 0, pois o valor 0 não é válido para a AWS; omitir desliga o autoscaling.
- **`manage_master_user_password` / `password`** — mutuamente exclusivos. Apenas um dos dois é enviado, nunca ambos, evitando erro da API.
- **`kms_key_id`** — só faz sentido quando há criptografia.
- **`final_snapshot_identifier`** — a AWS exige um nome de snapshot ao destruir, **a menos que** `skip_final_snapshot` seja true. A condicional cobre os dois casos.

---

## `kms.tf` — criptografia do armazenamento

```hcl
resource "aws_kms_key" "rds" {
  count               = local.create_kms_key_resource ? 1 : 0
  enable_key_rotation = true
  ...
}
```

Mesma lógica do módulo EKS: criptografia em repouso com uma key dedicada e rotação automática anual. O `count` baseado em `local.create_kms_key_resource` garante que a key só seja criada quando a criptografia está ligada, o usuário não passou uma key própria e pediu para o módulo criar.

A diferença para o EKS é o escopo: aqui a key criptografa o **volume de armazenamento** inteiro do banco (dados, logs, snapshots), não apenas secrets.

---

## `security_group.tf` — controle de acesso

```hcl
resource "aws_security_group" "rds" {
  count       = var.create_security_group ? 1 : 0
  name_prefix = "${var.name}-rds-"
  ...
  lifecycle {
    create_before_destroy = true
  }
}
```

**`create_before_destroy`** — security groups não podem ser deletados enquanto há recursos usando-os. Ao trocar algo que força recriação do SG, este lifecycle cria o novo SG antes de remover o antigo, evitando erro de dependência com a instância RDS que o referencia.

### Regras como recursos separados

```hcl
resource "aws_vpc_security_group_ingress_rule" "cidr" {
  for_each = var.create_security_group ? toset(var.allowed_cidr_blocks) : []

  cidr_ipv4   = each.value
  from_port   = local.port
  to_port     = local.port
  ip_protocol = "tcp"
}
```

O módulo usa `aws_vpc_security_group_ingress_rule` (um recurso por regra) em vez das regras inline dentro do `aws_security_group`. Isso é intencional: as regras inline causam *perpetual diffs* — qualquer mudança feita fora do Terraform, ou a própria ordenação das regras, gera diffs falsos a cada plan. Com recursos separados e `for_each`, cada regra tem identidade própria no state e é gerenciada de forma estável.

Há dois conjuntos de regras de ingress — um para CIDRs (`cidr_ipv4`) e outro para security groups de origem (`referenced_security_group_id`) — porque cada regra aceita apenas **um** tipo de origem. Ambos liberam exatamente a porta do banco (`local.port`), sem abrir faixas desnecessárias.

---

## `monitoring.tf` — Enhanced Monitoring

```hcl
resource "aws_iam_role" "monitoring" {
  count              = local.create_monitoring_role ? 1 : 0
  assume_role_policy = data.aws_iam_policy_document.monitoring_assume[0].json
}

resource "aws_iam_role_policy_attachment" "monitoring" {
  count      = local.create_monitoring_role ? 1 : 0
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}
```

O **Enhanced Monitoring** coleta métricas de SO da instância (CPU, memória, I/O por processo) em granularidade de segundos, mais detalhadas que as métricas padrão do CloudWatch. Para isso, o serviço RDS precisa de uma role que o autorize a publicar essas métricas — daí a trust policy para `monitoring.rds.amazonaws.com`.

A role só é criada quando `monitoring_interval > 0` (o monitoring está ligado) **e** `create_monitoring_role` é true. Caso contrário, o usuário pode apontar uma role existente via `monitoring_role_arn`.

---

## `parameter_group.tf` — ajustes da engine

```hcl
resource "aws_db_parameter_group" "rds" {
  count  = var.create_parameter_group ? 1 : 0
  family = var.parameter_group_family

  dynamic "parameter" {
    for_each = var.parameters
    content {
      name         = parameter.value.name
      value        = parameter.value.value
      apply_method = parameter.value.apply_method
    }
  }
}
```

O parameter group permite sobrescrever configurações da engine (ex.: `max_connections`, `shared_buffers`, `log_statement`). É opcional (`count` em `create_parameter_group`) porque a maioria dos bancos roda bem com os defaults da AWS.

O `dynamic "parameter"` gera um bloco por item da lista `parameters`. O `apply_method` (default `immediate`) controla quando o parâmetro entra em vigor: `immediate` aplica na hora; `pending-reboot` só após reiniciar a instância — necessário para parâmetros estáticos que não podem mudar com o banco em execução.

A `family` (ex.: `postgres16`) precisa casar com a engine e a versão major da instância — por isso é obrigatória quando o parameter group é criado.

---

## Por que o módulo não cria a rede

Diferente de um módulo "tudo em um", este recebe `vpc_id` e `subnet_ids` de fora. O motivo é o mesmo que levou a separar o módulo VPC: a rede tem ciclo de vida próprio e é compartilhada por vários recursos (EKS, RDS, ElastiCache...). Cada banco consome a rede existente, e múltiplos bancos são criados chamando o módulo várias vezes no consumer — cada chamada com seu próprio `name`, state isolado e configuração independente.

---

## Ordem de criação dos recursos

```
aws_partition (data)
  │
  ├─ aws_kms_key.rds ─► aws_kms_alias.rds
  │        │
  ├─ aws_security_group.rds ─► ingress/egress rules
  │        │
  ├─ aws_db_subnet_group.rds
  │        │
  ├─ aws_iam_role.monitoring ─► attachment   (se monitoring_interval > 0)
  │        │
  ├─ aws_db_parameter_group.rds              (se create_parameter_group)
  │        │
  └────────┴──────► aws_db_instance.main
```

A instância depende de quase tudo: subnet group (onde rodar), security group (quem acessa), KMS key (criptografia), role de monitoring e parameter group. O Terraform infere essas dependências automaticamente pelas referências de atributo (`aws_db_subnet_group.rds.name`, `local.kms_key_arn`, etc.), sem precisar de `depends_on` explícito.
