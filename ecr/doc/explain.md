# Explicação detalhada — módulo ECR

Este documento percorre cada arquivo do módulo explicando **o que o código faz e por quê foi escrito assim**.

O ECR é um registry regional e serverless: não há VPC, subnet nem security group. A superfície de decisão é pequena, mas quase toda ela tem consequência direta em **custo** (armazenamento acumulado) ou em **integridade da cadeia de entrega** (imutabilidade de tag). O módulo é enxuto por isso, não por ser trivial.

---

## Por que este módulo cria vários recursos

Os outros módulos da biblioteca criam um recurso por instância: um `aws_sqs_queue`, um `aws_dynamodb_table`, uma `aws_db_instance`. Aqui a escolha é outra, e vale explicar.

Repositórios de um mesmo sistema compartilham política: mesma imutabilidade, mesmo scan, mesma retenção. Instanciar o módulo cinco vezes significaria repetir cinco vezes a mesma configuração — e, se a criptografia por KMS estiver ligada, criar **cinco chaves**. A KMS é cobrada por chave por mês, independentemente de uso, e não há ganho de isolamento em separar chaves entre repositórios do mesmo sistema.

A alternativa considerada era um módulo singular mais um `for_each` no consumidor. Isso resolveria a repetição, mas devolveria o problema da chave: o `for_each` criaria uma por iteração.

---

## `variables.tf`

### `repository_names` como lista de nomes curtos

```hcl
variable "repository_names" {
  type = list(string)
  validation {
    condition = length(var.repository_names) > 0
  }
}
```

A validação existe porque dois outputs (`registry_id` e `registry_url`) indexam o primeiro elemento. Com lista vazia, o plan quebraria com um erro de índice sem relação óbvia com a causa; a validação falha antes, dizendo o que fazer.

### `namespace` separado do nome

O ECR aceita barras no nome do repositório (`togglemaster/auth-service`), o que agrupa visualmente no console. Separar namespace de nome mantém os **outputs indexados pelo nome curto**: o consumidor escreve `repository_urls["auth-service"]` e não precisa saber se há namespace nem qual é.

### `image_tag_mutability` com default `IMMUTABLE`

É o único default do módulo que contraria o default da AWS (`MUTABLE`), e é deliberado — ver a seção sobre imutabilidade adiante.

---

## `main.tf` — o map de repositórios

```hcl
locals {
  repositories = {
    for name in var.repository_names :
    name => var.namespace != null ? "${var.namespace}/${name}" : name
  }
}
```

A entrada é uma lista, mas o `for_each` opera sobre um **map**: chave = nome curto, valor = nome completo.

O motivo é o endereçamento no state. Com `for_each` sobre lista (via `toset`), o endereço seria `aws_ecr_repository.main["togglemaster/auth-service"]`. Com o map, fica `aws_ecr_repository.main["auth-service"]` — mais curto, e **estável se o namespace mudar**. Trocar o namespace ainda recria os repositórios (o nome é imutável na AWS), mas o diff do plan mostra a mudança de atributo em vez de uma remoção e uma adição em endereços diferentes.

`count` estava fora de cogitação: remover um repositório do meio da lista deslocaria os índices e o Terraform destruiria e recriaria todos os seguintes.

### O bloco de criptografia

```hcl
encryption_configuration {
  encryption_type = var.encryption_type
  kms_key         = local.use_kms ? local.kms_key_arn : null
}
```

O atributo `kms_key` só é aceito quando `encryption_type` é `KMS`; preenchê-lo com `AES256` é erro de API. E, mesmo com `KMS`, `null` é válido — significa "use a chave gerenciada padrão do ECR". Por isso o ternário aninhado com o `local.kms_key_arn`, que já é nulo quando não há chave própria nem informada.

Um detalhe que não aparece no código, mas define o comportamento: **a criptografia não pode ser alterada depois da criação**. Mudar `encryption_type` num repositório existente força recriação — e o Terraform não destrói repositório com imagens sem `force_delete`. Na prática, é uma decisão de dia 1.

---

## `lifecycle.tf` — a parte não óbvia do módulo

São três armadilhas empilhadas, e vale documentar cada uma porque nenhuma é evidente lendo o código pronto.

### 1. `jsonencode` no conjunto corrompe os números

O caminho natural seria montar a lista de regras e codificar tudo de uma vez:

```hcl
# NÃO funciona
jsonencode({ rules = concat(local.untagged_rule, local.retention_rule) })
```

As duas regras têm formatos de objeto diferentes — a de imagens sem tag tem `countUnit`, a de retenção não. Quando o Terraform precisa dar um tipo comum a elementos de uma lista, ele unifica para o tipo mais permissivo que sirva a todos: `map(string)`. O efeito é `countNumber` sair como `"7"` em vez de `7`, e o ECR rejeitar a policy — no schema dele `countNumber` é `integer`.

O detalhe traiçoeiro é que **o bug não aparece sempre**. Quando `tagPrefixList` está presente, o objeto tem um valor de lista, e a unificação para `map(string)` deixa de ser possível — os números sobrevivem. Ou seja: configurar prefixos mascara o problema, e a configuração padrão é justamente a que quebra.

A solução é codificar cada regra isoladamente, quando cada `jsonencode` ainda enxerga um objeto de formato fixo, e unir os documentos como texto:

```hcl
rule_documents             = concat(local.untagged_rule, local.retention_rule)  # list(string)
generated_lifecycle_policy = format("{\"rules\":[%s]}", join(",", local.rule_documents))
```

`concat` sobre `list(string)` não tem o que unificar.

### 2. A prioridade não pode ser fixa

O ECR avalia as regras em ordem crescente de `rulePriority` e exige que a regra com `tagStatus: "any"` seja a de **maior** prioridade numérica. Se vier antes de outra, a policy inteira é rejeitada.

```hcl
retention_priority = length(local.untagged_rule) + 1
```

Como a regra de imagens sem tag é opcional, a de retenção é a `1` quando aquela não existe e a `2` quando existe. A lista tem zero ou um elemento e serve de contador. Como a de retenção é sempre a última das duas, a restrição do `any` fica satisfeita automaticamente.

### 3. `tagged` e `any` são documentos diferentes

```hcl
retention_rule = var.max_tagged_images > 0 ? [
  local.restrict_by_prefix ? jsonencode({ ... tagStatus = "tagged", tagPrefixList = ... }) 
                           : jsonencode({ ... tagStatus = "any" })
] : []
```

O ECR exige `tagPrefixList` não vazio quando `tagStatus` é `tagged`, e o proíbe quando é `any`. Não é um campo opcional dentro de um mesmo documento — são dois documentos.

Um `merge` com map vazio para adicionar o campo condicionalmente também não serve: além de ser a mesma armadilha do item 1, o ternário entre dois objetos de formatos diferentes é recusado pelo Terraform com *"the true and false result expressions must have consistent types"*. Por isso o ternário fica **entre as strings já codificadas**, onde os dois ramos têm o mesmo tipo.

### Por que o recurso pode não existir

```hcl
apply_lifecycle_policy = var.create_lifecycle_policy && (
  var.lifecycle_policy != null || length(local.rule_documents) > 0
)
```

Com as duas variáveis numéricas em zero, a policy gerada seria `{"rules":[]}` — que o ECR rejeita. Em vez de deixar o apply falhar com um erro de API obscuro, o módulo simplesmente não cria o recurso.

O `coalesce(var.lifecycle_policy, local.generated_lifecycle_policy)` dá o escape hatch: quem precisa de uma regra que as variáveis não expressam passa o JSON inteiro.

---

## `kms.tf` — uma chave para todos

```hcl
resource "aws_kms_key" "ecr" {
  count = local.create_kms_key_resource ? 1 : 0
}
```

`count` e não `for_each`: é uma chave só, compartilhada. Essa é a consequência prática da decisão de o módulo criar vários repositórios — e o principal argumento a favor dela.

O alias usa `coalesce(var.namespace, var.repository_names[0])`. Aliases precisam ser únicos por conta e região; o namespace é o identificador natural quando existe, e o primeiro repositório serve de desempate quando não existe.

`enable_key_rotation = true` acompanha o padrão dos outros módulos da biblioteca.

---

## `ssm.tf` — a ponte para a esteira

A URL do repositório é `<account>.dkr.ecr.<region>.amazonaws.com/<namespace>/<nome>`. É derivável, mas derivá-la na esteira significa a pipeline conhecer account id, região e convenção de namespace — três coisas que mudam por ambiente.

Publicar no Parameter Store permite que o job faça:

```bash
REPO=$(aws ssm get-parameter --name /ecr/auth-service/repository-url --query Parameter.Value --output text)
```

sem ler o tfstate, que costuma estar num bucket com permissão restrita e cujo formato é detalhe interno do Terraform.

O parâmetro é `String` e não `SecureString`: uma URL de repositório não é segredo, e `SecureString` adicionaria dependência de KMS na leitura.

---

## `outputs.tf` — mapas, não listas

```hcl
value = { for k, v in aws_ecr_repository.main : k => v.repository_url }
```

Todos os outputs por repositório são mapas indexados pelo nome curto. Uma lista obrigaria o consumidor a saber a posição de cada repositório e a mantê-la sincronizada com a ordem de `repository_names` — acoplamento silencioso que quebra ao inserir um nome no meio.

### `registry_url`

```hcl
value = split("/", values(aws_ecr_repository.main)[0].repository_url)[0]
```

O ECR não expõe a URL base do registry como atributo — só a URL completa de cada repositório. Cortar na primeira barra é a forma direta de obtê-la, e ela é idêntica para todos os repositórios da conta e região, então qualquer um serve de fonte.

`values(...)[0]` e não `one(values(...))`: `one()` retorna o elemento único de uma coleção **e falha se houver mais de um**. Como o caso normal aqui são cinco repositórios, `one()` quebraria em todo uso realista do módulo.

---

## Imutabilidade de tag: o default que contraria a AWS

O default da AWS é `MUTABLE`. O deste módulo é `IMMUTABLE`, e a razão é a cadeia de entrega.

Numa esteira com tag derivada do commit (`v1.0.0-a1b2c3d`) e deploy por GitOps, o repositório de manifests registra a tag. O ArgoCD compara o Git com o cluster e sincroniza quando há diferença.

Sob `MUTABLE`, alguém pode republicar `v1.0.0-a1b2c3d` apontando para outro conteúdo. O Git não muda — a string da tag é a mesma —, o ArgoCD não vê diferença, e o cluster acaba rodando um artefato que passou por nenhum dos gates de segurança da esteira. O scan que rodou naquela tag não descreve mais a imagem que está em produção.

`IMMUTABLE` fecha isso na origem: o push é recusado. O custo é que a esteira não pode reaproveitar tags móveis (`latest`, `dev`) — o que, com tag por commit, não é limitação.

---

## O que o módulo não faz — e por quê

**Não configura enhanced scanning.** O `aws_ecr_registry_scanning_configuration` é **por registry**, ou seja, um singleton por conta e região. Se o módulo o gerenciasse, duas instâncias na mesma conta — cenário normal, um módulo por sistema — brigariam pelo mesmo recurso a cada apply, cada uma revertendo a configuração da outra. Recurso de escopo de conta pertence a um módulo de escopo de conta, não a este.

**Não cria as identidades de push.** A role que a esteira assume precisa de `ecr:GetAuthorizationToken` (que não aceita escopo por recurso, tem que ser `*`) mais as ações de push escopadas nos ARNs dos repositórios. Isso é composição de IAM, papel do módulo `iam-irsa` ou de uma role de CI — e depende de como a esteira autentica (OIDC do GitHub, usuário, role assumida), o que este módulo não tem como saber.

**Não faz replicação entre regiões.** `aws_ecr_replication_configuration` também é por registry, mesmo problema do enhanced scanning.
