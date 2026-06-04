# Exemplo de consumo do módulo SQS

Estrutura pronta para copiar. Cria uma fila Standard com dead-letter queue. O `source` aponta diretamente para o módulo publicado no GitHub (branch `main`).

## Estrutura

```
example/
├── main.tf                  # chamada do módulo sqs (source = github)
├── variables.tf
├── outputs.tf
├── versions.tf
└── terraform.tfvars.example
```

## Pré-requisitos

- Terraform >= 1.5
- Credenciais AWS configuradas

## Como usar

```bash
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan
terraform apply
```

## O que provisiona

- Fila Standard `demo-jobs` com visibility timeout de 60s e long polling (20s)
- Dead-letter queue `demo-jobs-dlq` com redrive após 5 tentativas
- Criptografia SSE-SQS (gerenciada pela AWS, sem custo de KMS)

## Observações

- Não há VPC: o SQS é um serviço regional acessado via API.
- Para subir mais de uma fila, adicione outro bloco `module "sqs_xxx"` com um `name` diferente.
- Para uma fila FIFO, defina `fifo_queue = true` (o sufixo `.fifo` é adicionado automaticamente).
- Para permitir que um serviço (SNS, EventBridge) envie mensagens, passe uma `policy` — ver o [README do módulo](../README.md#permitindo-que-um-serviço-envie-mensagens).
