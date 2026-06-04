# Explicação detalhada — módulo SQS

Este documento percorre cada arquivo do módulo explicando **o que o código faz e por quê foi escrito assim**.

Como o DynamoDB, o SQS é **serverless e regional**: não há VPC, subnet nem security group. O acesso é controlado por IAM (no lado do consumidor) e pela access policy da fila (para serviços/contas externas). Por isso o módulo é enxuto.

---

## `variables.tf`

### Standard vs. FIFO

```hcl
variable "fifo_queue" {
  type    = bool
  default = false
}
```

A escolha entre Standard e FIFO é a decisão estrutural da fila:

- **Standard** — throughput praticamente ilimitado, entrega *at-least-once* (pode duplicar) e ordem *best-effort* (pode reordenar). Default, serve à maioria.
- **FIFO** — ordem garantida e *exactly-once*, mas com limite de throughput. Use quando a ordem das mensagens importa (ex.: eventos de um mesmo agregado).

Várias variáveis (`content_based_deduplication`, `deduplication_scope`, `fifo_throughput_limit`) só fazem sentido em FIFO. No `main.tf` elas são anuladas quando a fila é Standard.

### Long polling

```hcl
variable "receive_wait_time_seconds" {
  default = 0
}
```

O default `0` é *short polling* — cada chamada de `ReceiveMessage` retorna imediatamente, mesmo sem mensagens, gerando muitas chamadas vazias (e custo). Definir um valor (até 20) ativa o *long polling*: a chamada espera até haver mensagem ou o tempo expirar. É uma das otimizações de custo mais simples do SQS; o exemplo usa 20.

---

## `main.tf` — locals, filas e policy

### locals — nomenclatura e criptografia

```hcl
locals {
  base_name  = endswith(var.name, ".fifo") ? trimsuffix(var.name, ".fifo") : var.name
  queue_name = var.fifo_queue ? "${local.base_name}.fifo" : local.base_name
  dlq_name   = var.fifo_queue ? "${local.base_name}-dlq.fifo" : "${local.base_name}-dlq"
  ...
}
```

Filas FIFO **exigem** que o nome termine em `.fifo` — esquecer disso é um erro comum. Estes locals tornam o sufixo automático: o usuário passa `events`, o módulo cria `events.fifo` e a DLQ `events-dlq.fifo`. O `base_name` remove um `.fifo` que o usuário porventura já tenha colocado, para não gerar `events.fifo.fifo` nem `events.fifo-dlq`.

```hcl
use_kms                 = var.create_kms_key || var.kms_master_key_id != null
create_kms_key_resource = var.create_kms_key && var.kms_master_key_id == null
kms_key_id              = var.kms_master_key_id != null ? var.kms_master_key_id : (local.create_kms_key_resource ? aws_kms_key.sqs[0].arn : null)
```

**`use_kms`** decide entre SSE-KMS e SSE-SQS. **`create_kms_key_resource`** só cria uma key se o usuário pediu (`create_kms_key`) e não informou uma existente. **`kms_key_id`** resolve qual key usar. Quando `use_kms` é false, as mensagens ainda são criptografadas — com a chave gerenciada SSE-SQS, sem custo.

### Dead-letter queue e a ordem da declaração

```hcl
resource "aws_sqs_queue" "dlq" {
  count = var.create_dlq ? 1 : 0
  ...
}

resource "aws_sqs_queue" "main" {
  ...
  redrive_policy = var.create_dlq ? jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq[0].arn
    maxReceiveCount     = var.max_receive_count
  }) : null
}
```

A DLQ é declarada **antes** da fila principal porque a principal referencia o ARN da DLQ no `redrive_policy`. Essa referência cria a dependência: o Terraform sempre cria a DLQ primeiro.

O `redrive_policy` é o coração do padrão de DLQ: depois que uma mensagem é recebida e não deletada `maxReceiveCount` vezes (ou seja, o processamento falhou repetidamente), o SQS a move automaticamente para a DLQ. Isso evita o cenário de *poison message* — uma mensagem defeituosa que trava o consumidor em loop infinito.

**Por que a DLQ não aponta de volta para a principal?** Existe um atributo `redrive_allow_policy` que restringe quais filas podem usar uma DLQ. Seria tentador configurá-lo na DLQ apontando para a fila principal, mas isso criaria uma **dependência circular** (principal → DLQ pelo redrive_policy, DLQ → principal pelo redrive_allow_policy), que o Terraform não consegue resolver. Por isso o módulo configura apenas o sentido principal → DLQ.

### Criptografia condicional nos atributos

```hcl
sqs_managed_sse_enabled           = local.use_kms ? null : true
kms_master_key_id                 = local.use_kms ? local.kms_key_id : null
kms_data_key_reuse_period_seconds = local.use_kms ? var.kms_data_key_reuse_period_seconds : null
```

`sqs_managed_sse_enabled` (SSE-SQS) e `kms_master_key_id` (SSE-KMS) são **mutuamente exclusivos** — definir os dois causa erro. O padrão `condição ? valor : null` garante que apenas um seja enviado: com KMS, liga os campos de KMS e omite o SSE-SQS; sem KMS, faz o oposto.

### Access policy separada

```hcl
resource "aws_sqs_queue_policy" "main" {
  count     = var.policy != null ? 1 : 0
  queue_url = aws_sqs_queue.main.id
  policy    = var.policy
}
```

A access policy é um recurso separado (`aws_sqs_queue_policy`), criado só quando o usuário fornece um documento. Ela serve para autorizar **quem está fora da conta ou serviços AWS** (SNS, EventBridge, S3) a enviar mensagens. Para consumidores dentro da conta (uma Lambda, um pod), o controle é feito pela policy IAM do consumidor referenciando o `queue_arn` — não aqui.

---

## `kms.tf` — criptografia opcional

```hcl
resource "aws_kms_key" "sqs" {
  count               = local.create_kms_key_resource ? 1 : 0
  enable_key_rotation = true
  ...
}
```

Mesma estrutura dos demais módulos: key dedicada com rotação automática, criada só quando solicitada. O alias usa `local.base_name` (sem o `.fifo`) para ficar legível.

---

## Por que não há security group

Reforçando a diferença em relação a RDS/EKS: o SQS não vive dentro da VPC. Não existe "liberar porta" para a fila. O controle de acesso é exclusivamente por identidade (IAM) e pela access policy da fila. Um consumidor recebe permissão assim:

```hcl
statement {
  effect    = "Allow"
  actions   = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"]
  resources = [module.sqs_jobs.queue_arn]
}
```

---

## Ordem de criação dos recursos

```
aws_kms_key.sqs ─► aws_kms_alias.sqs        (se create_kms_key)
       │
       ▼
aws_sqs_queue.dlq                            (se create_dlq)
       │  (arn referenciado no redrive_policy)
       ▼
aws_sqs_queue.main
       │
       ▼
aws_sqs_queue_policy.main                    (se policy informada)
```

No cenário mais simples (sem DLQ, sem KMS, sem policy), o módulo cria um único `aws_sqs_queue`.
