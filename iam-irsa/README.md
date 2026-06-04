# Módulo Terraform – IAM IRSA (IAM Roles for Service Accounts)

Cria uma IAM role assumível via o **OIDC provider do EKS** (IRSA), restrita a um ou mais
service accounts de um namespace, com permissões via policy inline (JSON) e/ou managed
policies. Opcionalmente publica o ARN da role no **SSM Parameter Store**.

É a peça que dá identidade AWS a um pod sem credenciais estáticas: o pod usa o
ServiceAccount anotado com o ARN da role, e o SDK da AWS troca o token do OIDC por
credenciais temporárias via `sts:AssumeRoleWithWebIdentity`.

> O módulo **não** cria o OIDC provider — ele vem do módulo `eks` (`enable_irsa = true`),
> que expõe `oidc_provider_arn` e `oidc_provider_url`. Uma role pode reunir permissões de
> vários serviços (ex.: SQS + DynamoDB), por isso é um módulo próprio e não acoplado a um
> módulo de recurso.

## Recursos criados

- `aws_iam_role` – a role IRSA, com trust policy federada ao OIDC do cluster
- `aws_iam_role_policy` – policies inline com as permissões (uma por entrada de `inline_policies`)
- `aws_iam_role_policy_attachment` – managed policies anexadas (uma por entrada de `policy_arns`)
- `aws_ssm_parameter` – ARN da role publicado no Parameter Store (opcional)

## Uso

```hcl
data "aws_iam_policy_document" "analytics" {
  statement {
    effect    = "Allow"
    actions   = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"]
    resources = [module.sqs.queue_arn]
  }
  statement {
    effect    = "Allow"
    actions   = ["dynamodb:PutItem"]
    resources = [module.dynamodb.table_arn]
  }
}

module "irsa_analytics" {
  source = "github.com/vitorfprado/terraform-aws-modules//iam-irsa?ref=main"

  name              = "role-eks-togglemaster-analytics"
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url

  namespace        = "togglemaster"
  service_accounts = ["analytics-service"]

  inline_policies = {
    app = data.aws_iam_policy_document.analytics.json
  }

  create_ssm_parameter = true

  tags = {
    Service = "analytics-service"
  }
}
```

Anote o ARN no ServiceAccount:

```yaml
metadata:
  annotations:
    eks.amazonaws.com/role-arn: <module.irsa_analytics.role_arn>
```

Um exemplo completo e copiável (VPC + EKS + 2 roles) está em [`example/`](./example).

## Vinculação ao service account

A trust policy restringe quem pode assumir a role pela claim `sub` do token OIDC:

- `service_accounts = ["analytics-service"]` → casa `system:serviceaccount:<namespace>:analytics-service` (StringEquals).
- Vários SAs na lista → qualquer um deles pode assumir (semântica OR).
- `service_accounts = ["*"]` → qualquer SA do namespace (StringLike `…:*`). Use com parcimônia.

A claim `aud` é sempre fixada em `sts.amazonaws.com`.

## Permissões: inline vs managed

- **`inline_policies`** — para permissões sob medida sobre ARNs específicos (a fila SQS, a tabela DynamoDB). Monte com `aws_iam_policy_document` no consumer e passe `{ rótulo = doc.json }`.
- **`policy_arns`** — para reaproveitar managed policies (AWS-managed como `AmazonS3ReadOnlyAccess`, ou customer-managed). Passe `{ rótulo = arn }`.

Os dois são `map(string)` e podem ser usados juntos.

> **Por que map e não string/list?** As permissões de uma role IRSA quase sempre referenciam
> ARNs criados **no mesmo apply** (a fila, a tabela), que são *known-after-apply*. Um `count`
> sobre `policy_json != null` ou um `for_each` sobre `toset(list_de_arns)` quebra com valor
> desconhecido. Com map, o `for_each` itera sobre as **chaves** (rótulos estáticos que você
> define) e os **valores** (JSON/ARN) podem ser computados sem quebrar o plan.

## SSM Parameter Store

Com `create_ssm_parameter = true`, o ARN da role é gravado no Parameter Store
(`/irsa/<name>/role-arn` por padrão, ou `ssm_parameter_name`). Isso permite que a geração
dos manifests e pipelines de CI resolvam o ARN para a annotation do ServiceAccount **sem
ler o tfstate** — desacoplando a camada de infra da camada de aplicação.

## Requisitos

| Nome      | Versão   |
|-----------|----------|
| terraform | >= 1.5   |
| aws       | >= 5.40  |

## Variáveis de entrada

| Nome | Descrição | Tipo | Padrão | Obrigatória |
|------|-----------|------|--------|:-----------:|
| `name` | Nome da role e prefixo dos recursos. | `string` | — | sim |
| `oidc_provider_arn` | ARN do OIDC provider (output do módulo eks). | `string` | — | sim |
| `oidc_provider_url` | URL do issuer OIDC sem https:// (output do módulo eks). | `string` | — | sim |
| `namespace` | Namespace do(s) service account(s). | `string` | — | sim |
| `service_accounts` | SAs autorizados a assumir a role (`["*"]` = todos do namespace). | `list(string)` | — | sim |
| `inline_policies` | Policies inline `{ rótulo = json }`. | `map(string)` | `{}` | não |
| `policy_arns` | Managed policies `{ rótulo = arn }`. | `map(string)` | `{}` | não |
| `max_session_duration` | Duração máxima da sessão (s). | `number` | `3600` | não |
| `create_ssm_parameter` | Publica o ARN da role no SSM. | `bool` | `false` | não |
| `ssm_parameter_name` | Nome do parâmetro SSM (null = `/irsa/<name>/role-arn`). | `string` | `null` | não |
| `tags` | Tags aplicadas a todos os recursos. | `map(string)` | `{}` | não |

## Outputs

| Nome | Descrição |
|------|-----------|
| `role_arn` | ARN da role (use na annotation do ServiceAccount). |
| `role_name` | Nome da role. |
| `role_unique_id` | ID único e estável da role. |
| `ssm_parameter_name` | Nome do parâmetro SSM, quando publicado. |
| `ssm_parameter_arn` | ARN do parâmetro SSM, quando publicado. |
