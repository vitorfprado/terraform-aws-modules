# Explicação detalhada — módulo DynamoDB

Este documento percorre cada arquivo do módulo explicando **o que o código faz e por quê foi escrito assim**.

Antes de entrar no código, um ponto que define a forma do módulo: o DynamoDB é **serverless e regional**. Não existe VPC, subnet, security group ou instância para provisionar — é um serviço acessado por API. Por isso este módulo é bem mais enxuto que o de RDS, e não recebe nada de rede como entrada.

---

## `variables.tf`

### Chaves e atributos — o ponto que mais confunde

```hcl
variable "attributes" {
  type = list(object({
    name = string
    type = string
  }))
}
```

DynamoDB é *schemaless* para a maioria dos campos: você grava qualquer atributo nos itens sem declará-lo. A exceção são os atributos usados como **chave** — partition key, sort key e as chaves dos índices (GSI/LSI). Esses precisam ter o tipo declarado (`S` string, `N` number, `B` binary) em `attributes`, porque o DynamoDB precisa saber o tipo para indexá-los.

Um erro comum é declarar todos os campos da aplicação em `attributes`. Só os atributos-chave entram aqui; declarar um atributo que não é chave causa erro no apply.

### Modo de cobrança

```hcl
variable "billing_mode" {
  default = "PAY_PER_REQUEST"
  validation {
    condition     = contains(["PAY_PER_REQUEST", "PROVISIONED"], var.billing_mode)
    error_message = "..."
  }
}
```

O `validation` falha cedo, no plan, se alguém digitar um valor inválido — melhor que um erro críptico da API no meio do apply. O default `PAY_PER_REQUEST` (on-demand) é a escolha recomendada para a maioria: escala sozinho, sem planejamento de capacidade.

---

## `main.tf` — locals e tabela

### locals

```hcl
locals {
  is_provisioned = var.billing_mode == "PROVISIONED"

  create_kms_key_resource = var.server_side_encryption_enabled && var.create_kms_key && var.kms_key_arn == null
  kms_key_arn             = var.kms_key_arn != null ? var.kms_key_arn : (local.create_kms_key_resource ? aws_kms_key.dynamodb[0].arn : null)
}
```

**`is_provisioned`** — calculado uma vez e reutilizado em todos os pontos onde a capacidade só faz sentido no modo provisionado (capacidade da tabela e dos GSIs). Evita repetir a comparação de string.

**`kms_key_arn`** — mesma cadeia de prioridade dos módulos RDS/EKS: key informada → key criada pelo módulo → `null`. A diferença aqui é o significado do `null`: no DynamoDB, `null` no bloco de criptografia não significa "sem criptografia", e sim "use a chave gerenciada `aws/dynamodb`". Os dados sempre são criptografados.

### A tabela e os blocos dinâmicos

O recurso `aws_dynamodb_table` usa `dynamic` para quase tudo, porque cada bloco é opcional e pode repetir:

```hcl
dynamic "attribute" {
  for_each = var.attributes
  content {
    name = attribute.value.name
    type = attribute.value.type
  }
}
```

**`attribute`** — um bloco por atributo-chave declarado.

**`global_secondary_index`** — um bloco por GSI. A capacidade usa o local `is_provisioned`:

```hcl
read_capacity  = local.is_provisioned ? global_secondary_index.value.read_capacity : null
```

No modo on-demand, passar capacidade causaria erro — então ela é omitida com `null`. No modo provisionado, ela é repassada.

**`local_secondary_index`** — LSIs não têm capacidade própria (compartilham a da tabela) e nem `hash_key` (usam a mesma da tabela), por isso o bloco é mais simples que o do GSI. LSIs também só podem ser criados junto com a tabela — não dá para adicionar depois sem recriar.

**`ttl`** — gerado só quando `ttl_enabled`. O TTL faz o DynamoDB apagar itens automaticamente quando o atributo de timestamp (epoch) informado fica no passado. Útil para sessões, caches e dados efêmeros, sem custo de escrita das deleções.

**`point_in_time_recovery`** — diferente dos outros, este bloco é **sempre** presente, com `enabled` controlado por variável. O PITR permite restaurar a tabela para qualquer segundo dos últimos 35 dias. O default é `true` porque é a proteção de dados mais relevante do DynamoDB e o custo é proporcional ao tamanho da tabela.

**`server_side_encryption`** — gerado só quando o usuário pede criptografia gerenciada por KMS. Sem o bloco, o DynamoDB usa a chave própria da AWS (owned key), que também criptografa, mas sem visibilidade/controle.

### O que este módulo deliberadamente não faz: auto scaling

O módulo **não** cria recursos de auto scaling (`aws_appautoscaling_target`/`policy`) para capacidade provisionada. Há dois motivos:

1. O modo `PAY_PER_REQUEST` (default) já escala automaticamente sem nenhuma configuração — para quem quer escala automática, é a resposta certa.
2. Auto scaling em modo provisionado exige `lifecycle { ignore_changes = [read_capacity, write_capacity] }` na tabela para o Terraform não brigar com o scaler. Como blocos `lifecycle` não podem ser condicionais, suportar os dois cenários (com e sem auto scaling) no mesmo recurso geraria *perpetual diffs* em um deles. Manter de fora deixa o módulo limpo e previsível.

Quem precisa de capacidade provisionada com escala automática deve, na prática, reavaliar se `PAY_PER_REQUEST` não resolve — quase sempre resolve.

---

## `kms.tf` — criptografia opcional

```hcl
resource "aws_kms_key" "dynamodb" {
  count               = local.create_kms_key_resource ? 1 : 0
  enable_key_rotation = true
  ...
}
```

Idêntico em estrutura ao dos módulos RDS e EKS: key dedicada com rotação automática, criada apenas quando o usuário liga a criptografia gerenciada **e** pede uma key própria. A diferença conceitual já mencionada: aqui a key é opcional de verdade, porque a ausência dela não deixa os dados sem criptografia — apenas usa uma chave gerenciada pela AWS.

---

## Por que não há security group nem VPC

Vale reforçar, porque é a maior diferença em relação aos outros módulos: o acesso ao DynamoDB é controlado **exclusivamente por IAM**, não por rede. Não existe "abrir a porta 3306 para o SG do EKS" como no RDS. Em vez disso, o consumidor recebe permissão via policy IAM referenciando o `table_arn`:

```hcl
resources = [
  module.dynamodb_orders.table_arn,
  "${module.dynamodb_orders.table_arn}/index/*",
]
```

O sufixo `/index/*` é necessário porque consultas a GSIs/LSIs são autorizadas separadamente da tabela base. Esquecer isso resulta em `AccessDenied` apenas nas queries que usam índices — um erro sutil e comum.

---

## Ordem de criação dos recursos

O grafo é simples — não há quase dependências:

```
aws_kms_key.dynamodb ─► aws_kms_alias.dynamodb   (se criptografia + create_kms_key)
        │
        └──► aws_dynamodb_table.main  (referencia local.kms_key_arn)
```

Quando a criptografia gerenciada não é usada, a tabela é o único recurso criado — o módulo se resume a um `aws_dynamodb_table` com seus blocos dinâmicos.
