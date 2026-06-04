# Exemplo de consumo do módulo DynamoDB

Estrutura pronta para copiar. Cria uma tabela com sort key, um GSI e TTL. O `source` aponta diretamente para o módulo publicado no GitHub (branch `main`).

## Estrutura

```
example/
├── main.tf                  # chamada do módulo dynamodb (source = github)
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

- Tabela DynamoDB `demo-orders` em modo on-demand (`PAY_PER_REQUEST`)
- Partition key `customer_id` + sort key `order_id`
- GSI `by-status` para consultar pedidos por status
- TTL no atributo `expires_at`
- Point-in-Time Recovery habilitado

## Observações

- Não há VPC: o DynamoDB é um serviço regional acessado via API.
- Para subir mais de uma tabela, adicione outro bloco `module "dynamodb_xxx"` com um `name` diferente.
- O atributo `status` é declarado em `attributes` porque é usado como chave do GSI — atributos que não são chave **não** devem ser declarados (DynamoDB é schemaless para os demais campos).
