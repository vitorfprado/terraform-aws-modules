# Módulo Terraform – ECR (Elastic Container Registry)

Cria um ou mais repositórios de imagens Docker com configuração compartilhada: imutabilidade de tag, scan no push, criptografia e lifecycle policy.

Diferente dos demais módulos da biblioteca, este cria **vários recursos por instância**. Repositórios de um mesmo sistema têm sempre a mesma política, e uma instância por repositório significaria uma KMS key por repositório — cobrada individualmente, sem nenhum ganho de isolamento.

## Recursos criados

| Recurso | Papel |
|---|---|
| `aws_ecr_repository` (um por nome) | O repositório de imagens |
| `aws_ecr_lifecycle_policy` | Expiração de imagens sem tag e retenção das mais recentes (opcional, ligada por padrão) |
| `aws_ecr_repository_policy` | Policy de acesso ao repositório (opcional, por repositório) |
| `aws_kms_key` + `aws_kms_alias` | Chave dedicada, compartilhada pelos repositórios (opcional) |
| `aws_ssm_parameter` | URL de cada repositório publicada no Parameter Store (opcional) |

## Uso

```hcl
module "ecr" {
  source = "github.com/fiap-tech-challenge-devops/terraform-aws-modules//ecr?ref=v1.0.0"

  namespace = "togglemaster"

  repository_names = [
    "auth-service",
    "flag-service",
    "targeting-service",
    "evaluation-service",
    "analytics-service",
  ]

  create_ssm_parameters = true

  tags = {
    Environment = "prod"
  }
}
```

Isso cria `togglemaster/auth-service`, `togglemaster/flag-service` e assim por diante. Um exemplo completo e copiável está em [`example/`](./example).

Os outputs são **mapas indexados pelo nome curto**, então o consumidor referencia sem saber do namespace:

```hcl
module.ecr.repository_urls["auth-service"]
# 123456789012.dkr.ecr.us-east-1.amazonaws.com/togglemaster/auth-service
```

## Tags imutáveis — o padrão é `IMMUTABLE`

Com `IMMUTABLE`, o ECR recusa um push que sobrescreva uma tag existente.

Isso importa quando a tag deriva do commit (`v1.0.0-a1b2c3d`) e o deploy é por GitOps: a tag registrada no repositório de manifests precisa apontar para sempre à mesma imagem. Sob `MUTABLE`, alguém republica a tag com outro conteúdo, o ArgoCD não vê diferença nenhuma no Git, e o cluster passa a rodar um artefato que ninguém revisou.

Use `MUTABLE` apenas se a esteira reaproveita tags móveis (`latest`, `dev`).

## Lifecycle policy

Ligada por padrão, com duas regras:

| Prioridade | Regra | Variável |
|---|---|---|
| 1 | Expira imagens **sem tag** após N dias | `untagged_image_expiration_days` (7) |
| 2 | Mantém as **N imagens com tag** mais recentes | `max_tagged_images` (30) |

Sem ela, toda imagem publicada é armazenada e cobrada indefinidamente — numa esteira que builda a cada merge, isso cresce rápido.

Imagens sem tag aparecem quando uma tag é reapontada ou um build multi-arch é sobrescrito. Não servem para rollback, então expiram cedo.

Ajustes:

- `lifecycle_tag_prefixes = ["v"]` restringe a regra de retenção às tags com esse prefixo. Sem ele, a regra vale para todas as imagens com tag.
- `lifecycle_policy` substitui as regras geradas por um documento JSON completo.
- `max_tagged_images = 0` e `untagged_image_expiration_days = 0` desligam cada regra individualmente. Com as duas em zero, nenhum recurso de lifecycle é criado.

> A regra de retenção usa `tagStatus: "any"` quando não há prefixos, e o ECR exige que uma regra `any` seja a de maior prioridade. Por isso as prioridades são calculadas, e não fixas.

## Criptografia

O padrão é `AES256` — chave gerenciada pela AWS, sem custo. Com `encryption_type = "KMS"` você pode usar uma chave própria:

```hcl
encryption_type = "KMS"
create_kms_key  = true   # ou passe kms_key_arn de uma chave existente
```

Vale quando você precisa de trilha de auditoria em CloudTrail ou de controlar o acesso pela key policy. A chave é única para todos os repositórios do módulo.

> A criptografia de um repositório **não pode ser alterada depois de criado**. Mudar `encryption_type` força a recriação — e o Terraform não destrói repositório com imagem dentro sem `force_delete`.

## Pontos de atenção

**Destroy com imagens.** `terraform destroy` falha em repositório não vazio. `force_delete = true` resolve, mas apaga as imagens junto — reserve para ambiente efêmero.

**Scan básico vs. enhanced.** `scan_on_push` liga o scan básico, por repositório. O *enhanced scanning* (via Inspector) é configurado **por registry**, ou seja, uma vez por conta/região — um recurso singleton. O módulo não o gerencia de propósito: duas instâncias do módulo na mesma conta brigariam pelo mesmo recurso a cada apply.

**Permissão de push.** O módulo cria os repositórios, não as identidades. A role que a esteira assume precisa de `ecr:GetAuthorizationToken` (em `*`) mais as ações de push escopadas nos ARNs — que saem em `repository_arns`.

## Requisitos

| Nome      | Versão   |
|-----------|----------|
| terraform | >= 1.5   |
| aws       | >= 5.40  |

## Variáveis de entrada

| Nome | Descrição | Tipo | Padrão | Obrigatória |
|------|-----------|------|--------|:-----------:|
| `repository_names` | Nomes curtos dos repositórios. | `list(string)` | — | sim |
| `namespace` | Prefixo antes da barra (null = sem namespace). | `string` | `null` | não |
| `image_tag_mutability` | `MUTABLE` ou `IMMUTABLE`. | `string` | `"IMMUTABLE"` | não |
| `scan_on_push` | Scan básico a cada push. | `bool` | `true` | não |
| `force_delete` | Permite destruir repositório com imagens. | `bool` | `false` | não |
| `encryption_type` | `AES256` ou `KMS`. | `string` | `"AES256"` | não |
| `create_kms_key` | Cria KMS key dedicada (só com `KMS`). | `bool` | `false` | não |
| `kms_key_arn` | KMS key existente (precede `create_kms_key`). | `string` | `null` | não |
| `kms_key_deletion_window_in_days` | Janela de exclusão da chave (7–30). | `number` | `30` | não |
| `create_lifecycle_policy` | Aplica a lifecycle policy. | `bool` | `true` | não |
| `untagged_image_expiration_days` | Dias até expirar imagens sem tag (0 = desliga). | `number` | `7` | não |
| `max_tagged_images` | Imagens com tag a manter (0 = desliga). | `number` | `30` | não |
| `lifecycle_tag_prefixes` | Restringe a retenção a esses prefixos. | `list(string)` | `[]` | não |
| `lifecycle_policy` | JSON completo, substitui as regras geradas. | `string` | `null` | não |
| `repository_policies` | Policies por repositório `{ nome = json }`. | `map(string)` | `{}` | não |
| `create_ssm_parameters` | Publica as URLs no Parameter Store. | `bool` | `false` | não |
| `ssm_parameter_prefix` | Prefixo dos parâmetros (null = `/ecr`). | `string` | `null` | não |
| `tags` | Tags aplicadas a todos os recursos. | `map(string)` | `{}` | não |

## Outputs

| Nome | Descrição |
|------|-----------|
| `repository_urls` | URL de cada repositório, por nome curto (destino do push). |
| `repository_arns` | ARN de cada repositório, por nome curto (para policies IAM). |
| `repository_names` | Nome completo (com namespace), por nome curto. |
| `registry_id` | ID do registry (conta AWS). |
| `registry_url` | URL base do registry (alvo do `docker login`). |
| `kms_key_arn` | ARN da KMS key criada, quando aplicável. |
| `ssm_parameter_names` | Parâmetros publicados, por nome curto. |
