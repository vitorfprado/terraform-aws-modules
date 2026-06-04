# Explicação detalhada — módulo iam-irsa

Este documento percorre cada arquivo do módulo explicando **o que o código faz e por quê foi escrito assim**.

IRSA (IAM Roles for Service Accounts) é o mecanismo que dá identidade AWS a um pod **sem
credenciais estáticas**. O fluxo: o ServiceAccount do pod é anotado com o ARN de uma IAM
role; o pod recebe um token JWT do OIDC do cluster; o SDK da AWS troca esse token por
credenciais temporárias via `sts:AssumeRoleWithWebIdentity`. A role só é assumível se a
trust policy aceitar aquele OIDC **e** aquele service account.

## Por que um módulo próprio (e não dentro do eks ou do sqs/dynamodb)

- Uma única role frequentemente reúne permissões de **vários serviços** (o analytics-service
  precisa de SQS **e** DynamoDB). Se a IRSA morasse no módulo `sqs`, não daria para anexar
  DynamoDB sem referência cruzada. Identidade que cruza recursos não cabe num módulo de recurso.
- A direção da dependência fica correta: o OIDC vem do `eks` e os ARNs vêm do `sqs`/`dynamodb`
  — ambos são **entradas** deste módulo. Embutir no `eks` faria o módulo de cluster depender
  das aplicações, invertendo a ordem natural (cluster antes das apps).
- O mesmo módulo serve tanto para roles de aplicação quanto para roles de addons (LBC, ESO).

É o mesmo desenho do `terraform-aws-modules/iam` oficial, onde o `iam-role-for-service-accounts-eks` é um submódulo separado.

---

## `variables.tf`

### `service_accounts` com validação

```hcl
variable "service_accounts" {
  type = list(string)
  validation {
    condition     = length(var.service_accounts) > 0
    error_message = "Informe ao menos um service account..."
  }
}
```

A lista nunca pode ser vazia: uma role IRSA sem `sub` na condição seria assumível por
qualquer SA de qualquer namespace daquele cluster — exatamente o que queremos evitar. A
validação falha cedo, no plan, em vez de gerar uma trust policy perigosa.

### `policy_json` e `policy_arns` separados

Permissões têm duas naturezas: sob medida (ARNs específicos → `policy_json`, montado com
`aws_iam_policy_document` no consumer) e reaproveitáveis (managed policies → `policy_arns`).
Manter as duas vias permite combinar, e nenhuma é obrigatória — uma role pode existir só
para ser referência de confiança.

---

## `main.tf` — locals e trust policy

### locals

```hcl
oidc_url   = replace(var.oidc_provider_url, "https://", "")
wildcard   = contains(var.service_accounts, "*")
sub_test   = local.wildcard ? "StringLike" : "StringEquals"
sub_values = local.wildcard
  ? ["system:serviceaccount:${var.namespace}:*"]
  : [for sa in var.service_accounts : "system:serviceaccount:${var.namespace}:${sa}"]
```

- `oidc_url` — o output do `eks` já vem sem `https://`, mas o `replace` torna a entrada
  idempotente caso alguém passe a URL com esquema.
- A escolha **StringEquals vs StringLike** é o ponto central: para SAs nomeados usamos
  igualdade exata (mais seguro); só quando há `*` caímos para `StringLike`, que aceita
  curinga. Misturar curinga em StringEquals não funcionaria — o `*` seria literal.

### A condição `sub` e a condição `aud`

```hcl
condition {
  test     = "StringEquals"
  variable = "${local.oidc_url}:aud"
  values   = ["sts.amazonaws.com"]
}
condition {
  test     = local.sub_test
  variable = "${local.oidc_url}:sub"
  values   = local.sub_values
}
```

A `aud` (audience) é sempre `sts.amazonaws.com` — é o público esperado do token quando o uso
é STS. A `sub` (subject) é o que amarra a role ao service account: `system:serviceaccount:<ns>:<sa>`.
Sem a condição de `sub`, qualquer workload do cluster poderia assumir a role.

### A role e as permissões

```hcl
resource "aws_iam_role" "irsa" {
  name               = var.name
  assume_role_policy = data.aws_iam_policy_document.assume.json
  max_session_duration = var.max_session_duration
}

resource "aws_iam_role_policy" "inline" {
  count = var.policy_json != null ? 1 : 0
  ...
}

resource "aws_iam_role_policy_attachment" "managed" {
  for_each = toset(var.policy_arns)
  ...
}
```

A policy inline é condicional (`count`) — só existe se `policy_json` for informado. As managed
policies usam `for_each` sobre o conjunto de ARNs. Por isso a documentação pede ARNs
**conhecidos no plan**: um ARN *known-after-apply* como chave de `for_each` faria o plan
falhar (mesma limitação que aparece em qualquer `for_each` sobre valor computado).

---

## `ssm.tf` — publicação opcional do ARN

```hcl
locals {
  ssm_parameter_name = coalesce(var.ssm_parameter_name, "/irsa/${var.name}/role-arn")
}

resource "aws_ssm_parameter" "role_arn" {
  count = var.create_ssm_parameter ? 1 : 0
  name  = local.ssm_parameter_name
  type  = "String"
  value = aws_iam_role.irsa.arn
}
```

Por que SSM aqui? O ARN da role é justamente o dado que a **camada de aplicação** precisa
(para a annotation `eks.amazonaws.com/role-arn`). Publicá-lo no Parameter Store cria um ponto
de integração estável: a geração dos manifests, o ESO ou um job de CI leem
`/irsa/<name>/role-arn` e injetam o ARN, **sem acoplar a aplicação ao tfstate da infra**.

É um `String` simples (não `SecureString`): um ARN não é segredo. O `count` mantém o recurso
opcional — quem não usa SSM não paga o parâmetro nem polui o Parameter Store.

> Este é o ponto onde o SSM "encaixou" naturalmente. Para publicar **strings de conexão**
> (RDS/Redis) como `SecureString` e alimentar o External Secrets, o lugar adequado é um
> módulo `ssm-parameter`/`secrets` dedicado — não a role de identidade.

---

## `outputs.tf`

Expõe `role_arn` (o dado mais usado — vai na annotation), `role_name` e `role_unique_id`
(estável, útil para condições de IAM), além de `ssm_parameter_name`/`ssm_parameter_arn`
(resolvidos via `try(...[0], null)` para retornarem `null` quando o SSM está desligado).

---

## Ordem de criação dos recursos

```
data.aws_iam_policy_document.assume
        │
        └──► aws_iam_role.irsa ──► aws_iam_role_policy.inline           (se policy_json)
                    │            └► aws_iam_role_policy_attachment.managed (por ARN)
                    │
                    └──► aws_ssm_parameter.role_arn                      (se create_ssm_parameter)
```

Tudo é inferido por referência de atributo; não há `depends_on` explícito.
