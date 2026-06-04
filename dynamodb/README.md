# Módulo Terraform – DynamoDB

Provisiona uma tabela Amazon DynamoDB com suporte a índices secundários (GSI/LSI), TTL, Point-in-Time Recovery, Streams e criptografia opcional via KMS.

Diferente dos módulos de VPC, EKS e RDS, o DynamoDB é **serverless e regional** — não há VPC, subnets ou security groups envolvidos. O módulo não recebe rede como entrada. Para múltiplas tabelas, chame o módulo várias vezes no consumer.

## Recursos criados

- `aws_dynamodb_table` – a tabela
- `aws_kms_key` / `aws_kms_alias` – criptografia com key dedicada (opcional)

## Uso

```hcl
module "dynamodb_sessions" {
  source = "github.com/vitorfprado/terraform-aws-modules//dynamodb?ref=main"

  name     = "sessions"
  hash_key = "session_id"

  attributes = [
    { name = "session_id", type = "S" },
  ]

  ttl_enabled        = true
  ttl_attribute_name = "expires_at"

  tags = {
    Environment = "producao"
  }
}
```

Exemplo com sort key e GSI:

```hcl
module "dynamodb_orders" {
  source = "github.com/vitorfprado/terraform-aws-modules//dynamodb?ref=main"

  name      = "orders"
  hash_key  = "customer_id"
  range_key = "order_id"

  attributes = [
    { name = "customer_id", type = "S" },
    { name = "order_id", type = "S" },
    { name = "status", type = "S" },
  ]

  global_secondary_indexes = [
    {
      name            = "by-status"
      hash_key        = "status"
      range_key       = "order_id"
      projection_type = "ALL"
    },
  ]
}
```

Um exemplo completo e copiável está em [`example/`](./example).

## Modos de cobrança

- **`PAY_PER_REQUEST`** (padrão) — on-demand. Escala automaticamente conforme a demanda, sem planejamento de capacidade. Recomendado para a maioria dos casos e para cargas imprevisíveis.
- **`PROVISIONED`** — capacidade fixa (`read_capacity`/`write_capacity`). Mais econômico para cargas constantes e previsíveis. Neste modo, as capacidades dos GSIs também devem ser informadas.

> Este módulo não gerencia auto scaling de capacidade provisionada. Se você precisa de escala automática, o modo `PAY_PER_REQUEST` já faz isso nativamente, sem configuração.

## Criptografia

DynamoDB **sempre** criptografa os dados em repouso. O que muda é a chave:

| Configuração | Chave usada | Custo de key |
|---|---|---|
| `server_side_encryption_enabled = false` (padrão) | Chave própria da AWS (owned) | nenhum |
| `enabled = true`, `create_kms_key = false` | Key gerenciada `aws/dynamodb` | nenhum |
| `enabled = true`, `create_kms_key = true` | KMS key dedicada criada pelo módulo | cobrança de KMS |
| `enabled = true`, `kms_key_arn = "..."` | KMS key existente informada | conforme a key |

Use uma KMS key dedicada quando precisar de controle de acesso à chave, auditoria por CloudTrail ou políticas de compliance.

## Requisitos

| Nome      | Versão   |
|-----------|----------|
| terraform | >= 1.5   |
| aws       | >= 5.40  |

## Variáveis de entrada

| Nome | Descrição | Tipo | Padrão | Obrigatória |
|------|-----------|------|--------|:-----------:|
| `name` | Nome da tabela. | `string` | — | sim |
| `hash_key` | Atributo da partition key. | `string` | — | sim |
| `attributes` | Atributos-chave (name + type S/N/B). | `list(object)` | — | sim |
| `range_key` | Atributo da sort key. | `string` | `null` | não |
| `billing_mode` | PAY_PER_REQUEST ou PROVISIONED. | `string` | `"PAY_PER_REQUEST"` | não |
| `read_capacity` | RCU (modo PROVISIONED). | `number` | `null` | não |
| `write_capacity` | WCU (modo PROVISIONED). | `number` | `null` | não |
| `table_class` | STANDARD ou STANDARD_INFREQUENT_ACCESS. | `string` | `"STANDARD"` | não |
| `global_secondary_indexes` | Lista de GSIs. | `list(object)` | `[]` | não |
| `local_secondary_indexes` | Lista de LSIs. | `list(object)` | `[]` | não |
| `ttl_enabled` | Habilita TTL. | `bool` | `false` | não |
| `ttl_attribute_name` | Atributo do TTL. | `string` | `null` | não |
| `point_in_time_recovery_enabled` | Habilita PITR. | `bool` | `true` | não |
| `stream_enabled` | Habilita Streams. | `bool` | `false` | não |
| `stream_view_type` | Conteúdo do stream. | `string` | `null` | não |
| `server_side_encryption_enabled` | Criptografia gerenciada por KMS. | `bool` | `false` | não |
| `create_kms_key` | Cria KMS key dedicada. | `bool` | `true` | não |
| `kms_key_arn` | KMS key existente. | `string` | `null` | não |
| `kms_key_deletion_window_in_days` | Janela de exclusão da KMS key. | `number` | `30` | não |
| `deletion_protection_enabled` | Proteção contra exclusão. | `bool` | `false` | não |
| `tags` | Tags aplicadas a todos os recursos. | `map(string)` | `{}` | não |

### Estrutura de `global_secondary_indexes`

```hcl
global_secondary_indexes = [
  {
    name               = "by-status"          # nome do índice
    hash_key           = "status"             # partition key do índice
    range_key          = "order_id"           # opcional
    projection_type    = "ALL"                # ALL, KEYS_ONLY ou INCLUDE
    non_key_attributes = null                 # obrigatório se projection_type = INCLUDE
    read_capacity      = null                 # apenas billing_mode PROVISIONED
    write_capacity     = null                 # apenas billing_mode PROVISIONED
  }
]
```

> Todo atributo usado como `hash_key`/`range_key` de um GSI ou LSI também precisa estar declarado em `attributes`.

## Outputs

| Nome | Descrição |
|------|-----------|
| `table_name` | Nome da tabela. |
| `table_id` | ID da tabela (igual ao nome). |
| `table_arn` | ARN da tabela (use em políticas IAM). |
| `table_stream_arn` | ARN do stream, quando habilitado. |
| `table_stream_label` | Label do stream, quando habilitado. |
| `kms_key_arn` | ARN da KMS key da criptografia, quando aplicável. |

## Dando acesso à tabela

Para que uma aplicação (pod no EKS via IRSA, função Lambda, etc.) acesse a tabela, use o output `table_arn` na policy IAM do consumidor:

```hcl
statement {
  effect    = "Allow"
  actions   = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:Query"]
  resources = [
    module.dynamodb_orders.table_arn,
    "${module.dynamodb_orders.table_arn}/index/*",  # inclui os GSIs/LSIs
  ]
}
```
