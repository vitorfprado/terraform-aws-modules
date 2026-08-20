# Módulo Terraform – SQS

Provisiona uma fila Amazon SQS (Standard ou FIFO) com dead-letter queue opcional, criptografia (SSE-SQS por padrão ou SSE-KMS) e access policy opcional.

Como o DynamoDB, o SQS é **serverless e regional** — não há VPC nem security group. O acesso é controlado por IAM e pela access policy da fila. Para múltiplas filas, chame o módulo várias vezes no consumer.

## Recursos criados

- `aws_sqs_queue` – a fila principal
- `aws_sqs_queue` – a dead-letter queue (opcional)
- `aws_sqs_queue_policy` – access policy da fila (opcional)
- `aws_kms_key` / `aws_kms_alias` – criptografia com key dedicada (opcional)

## Uso

```hcl
module "sqs_jobs" {
  source = "github.com/fiap-tech-challenge-devops/terraform-aws-modules//sqs?ref=main"

  name = "jobs"

  visibility_timeout_seconds = 60
  receive_wait_time_seconds  = 20  # long polling

  create_dlq        = true
  max_receive_count = 5

  tags = {
    Environment = "producao"
  }
}
```

Fila FIFO:

```hcl
module "sqs_events" {
  source = "github.com/fiap-tech-challenge-devops/terraform-aws-modules//sqs?ref=main"

  name                        = "events"   # vira "events.fifo"
  fifo_queue                  = true
  content_based_deduplication = true
}
```

Um exemplo completo e copiável está em [`example/`](./example).

## Dead-letter queue

Por padrão (`create_dlq = true`), o módulo cria uma segunda fila e configura o *redrive policy* da fila principal apontando para ela. Mensagens que falham no processamento `max_receive_count` vezes são movidas automaticamente para a DLQ, em vez de ficarem em loop infinito. A DLQ tem retenção maior (14 dias por padrão) para dar tempo de investigar as falhas.

Para uma fila FIFO, a DLQ também é criada como FIFO automaticamente.

## Criptografia

Toda mensagem no SQS é criptografada em repouso. O que muda é a chave:

| Configuração | Chave usada | Custo de key |
|---|---|---|
| padrão (`kms_master_key_id` nulo, `create_kms_key = false`) | SSE-SQS (gerenciada pela AWS) | nenhum |
| `create_kms_key = true` | KMS key dedicada criada pelo módulo | cobrança de KMS |
| `kms_master_key_id = "..."` | KMS key existente (CMK ou alias) | conforme a key |

SSE-KMS é necessário quando você precisa de controle de acesso à chave ou de criptografia compartilhada com outro serviço (ex.: SNS publicando em SQS com a mesma CMK).

## Requisitos

| Nome      | Versão   |
|-----------|----------|
| terraform | >= 1.5   |
| aws       | >= 5.40  |

## Variáveis de entrada

| Nome | Descrição | Tipo | Padrão | Obrigatória |
|------|-----------|------|--------|:-----------:|
| `name` | Nome da fila (sufixo .fifo automático em FIFO). | `string` | — | sim |
| `fifo_queue` | Cria fila FIFO. | `bool` | `false` | não |
| `content_based_deduplication` | Deduplicação por conteúdo (FIFO). | `bool` | `false` | não |
| `deduplication_scope` | Escopo de deduplicação (FIFO). | `string` | `null` | não |
| `fifo_throughput_limit` | Limite de throughput (FIFO). | `string` | `null` | não |
| `visibility_timeout_seconds` | Visibility timeout. | `number` | `30` | não |
| `message_retention_seconds` | Retenção das mensagens. | `number` | `345600` | não |
| `max_message_size` | Tamanho máximo da mensagem (bytes). | `number` | `262144` | não |
| `delay_seconds` | Atraso de entrega. | `number` | `0` | não |
| `receive_wait_time_seconds` | Long polling. | `number` | `0` | não |
| `create_dlq` | Cria dead-letter queue. | `bool` | `true` | não |
| `max_receive_count` | Tentativas antes de ir para a DLQ. | `number` | `5` | não |
| `dlq_message_retention_seconds` | Retenção na DLQ. | `number` | `1209600` | não |
| `kms_master_key_id` | KMS key existente (SSE-KMS). | `string` | `null` | não |
| `create_kms_key` | Cria KMS key dedicada. | `bool` | `false` | não |
| `kms_key_deletion_window_in_days` | Janela de exclusão da KMS key. | `number` | `30` | não |
| `kms_data_key_reuse_period_seconds` | Reuso da data key (SSE-KMS). | `number` | `300` | não |
| `policy` | Access policy da fila (JSON). | `string` | `null` | não |
| `tags` | Tags aplicadas a todos os recursos. | `map(string)` | `{}` | não |

## Outputs

| Nome | Descrição |
|------|-----------|
| `queue_url` | URL da fila (para enviar/receber mensagens). |
| `queue_arn` | ARN da fila (políticas IAM, event source de Lambda). |
| `queue_name` | Nome da fila. |
| `dlq_url` | URL da DLQ, quando criada. |
| `dlq_arn` | ARN da DLQ, quando criada. |
| `dlq_name` | Nome da DLQ, quando criada. |
| `kms_key_arn` | ARN da KMS key dedicada, quando criada. |

## Permitindo que um serviço envie mensagens

Para um tópico SNS publicar na fila, passe uma access policy via `policy`:

```hcl
data "aws_iam_policy_document" "sns_to_sqs" {
  statement {
    effect    = "Allow"
    actions   = ["sqs:SendMessage"]
    resources = [module.sqs_jobs.queue_arn]

    principals {
      type        = "Service"
      identifiers = ["sns.amazonaws.com"]
    }

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_sns_topic.example.arn]
    }
  }
}

module "sqs_jobs" {
  source = "github.com/fiap-tech-challenge-devops/terraform-aws-modules//sqs?ref=main"
  name   = "jobs"
  policy = data.aws_iam_policy_document.sns_to_sqs.json
}
```

Para um consumer (pod no EKS via IRSA, Lambda, etc.), conceda as permissões na policy IAM do consumidor referenciando `queue_arn` — não na policy da fila.
