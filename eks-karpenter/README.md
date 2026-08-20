# Módulo Terraform – EKS Karpenter (infraestrutura AWS)

Cria **toda a infraestrutura AWS** que o [Karpenter](https://karpenter.sh) precisa para operar em um cluster EKS existente: a IAM role dos nós provisionados, a IRSA do controller, a fila SQS de interrupção e as regras do EventBridge que a alimentam.

O módulo **não instala o chart Helm** e **não exige os providers `helm`/`kubernetes`** — só `aws`. A instalação do controller fica com quem consome (Helm CLI, `helm_release` no root, ou GitOps), usando os outputs.

> **Por que a separação?** O plano AWS (IAM, SQS, EventBridge) e o plano Kubernetes (o chart) têm ciclos de vida muito diferentes: a API do IAM não muda há anos, o chart do Karpenter quebra entre versões menores do Kubernetes. Mantê-los no mesmo módulo obriga a versionar os dois no mesmo ritmo. Separados, este módulo entra em qualquer root module num apply só, sem provider apontando para um cluster que talvez ainda não exista.

## Recursos criados

| Recurso | Papel |
|---|---|
| `aws_iam_role` (nós) + 4 `aws_iam_role_policy_attachment` | Identidade das instâncias EC2 provisionadas pelo Karpenter |
| `aws_eks_access_entry` (`EC2_LINUX`) | Autoriza os nós a se registrarem no cluster |
| `module.controller_role` (via [`../iam-irsa`](../iam-irsa)) | IRSA do controller, com a policy do Karpenter inline |
| `aws_sqs_queue` + `aws_sqs_queue_policy` | Fila de interrupção |
| 4 × `aws_cloudwatch_event_rule` + `aws_cloudwatch_event_target` | Spot interruption, rebalance, state change e health event → fila |
| `aws_ssm_parameter` | Publicação dos valores para a camada de manifests (opcional) |

## Uso

```hcl
module "karpenter" {
  source = "github.com/fiap-tech-challenge-devops/terraform-aws-modules//eks-karpenter?ref=v1.0.0"

  cluster_name      = module.eks.cluster_name
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url

  create_ssm_parameters = true

  tags = {
    Environment = "prod"
  }
}
```

Um exemplo completo e copiável (VPC + EKS + Karpenter) está em [`example/`](./example).

## Instalando o chart

Os três valores que a instalação precisa saem como output:

```hcl
settings.clusterName                                = var.cluster_name
settings.interruptionQueue                          = module.karpenter.interruption_queue_name
serviceAccount.annotations."eks.amazonaws.com/role-arn" = module.karpenter.controller_role_arn
```

Ou, prontos como mapa, em `module.karpenter.helm_values`:

```bash
terraform output -json helm_values | jq . > karpenter-values.yaml
helm upgrade --install karpenter oci://public.ecr.aws/karpenter/karpenter \
  --version "1.3.3" --namespace kube-system -f karpenter-values.yaml
```

> **A versão do chart é escolha sua** — o módulo não tem opinião nem default. Karpenter `>= 1.2` é necessário para Kubernetes 1.32; abaixo disso o controller sobe e morre com `not compatible with K8s version 1.32`.

### `EC2NodeClass`

O `spec.role` do `EC2NodeClass` recebe o **nome** (não o ARN) da role dos nós — output `node_role_name`. O Karpenter monta o instance profile a partir dele.

## Nomes determinísticos

Os recursos usam nomes previsíveis, derivados de `cluster_name`, em vez de `name_prefix`:

| Recurso | Nome padrão |
|---|---|
| Role do controller | `<cluster_name>-karpenter-controller` |
| Role dos nós | `<cluster_name>-karpenter-node` |
| Fila de interrupção | `<cluster_name>-karpenter` |

Isso permite que os manifests do cluster referenciem os valores como string estável, sem resolver output de Terraform em tempo de render. Cada um pode ser sobrescrito (`controller_role_name`, `node_role_name`, `interruption_queue_name`).

> **Trade-off:** com nome fixo, uma substituição da role não tem o `create_before_destroy` implícito do `name_prefix`. Como o nome já é escopado pelo cluster, colisão é improvável — mas se você cria e destrói o mesmo cluster em sequência rápida, pode esbarrar em `EntityAlreadyExists`.

## SSM Parameter Store

Com `create_ssm_parameters = true`, o módulo publica em `/karpenter/<cluster_name>/`:

| Parâmetro | Conteúdo |
|---|---|
| `controller-role-arn` | ARN da IRSA do controller |
| `node-role-name` | Nome da role dos nós |
| `interruption-queue-name` | Nome da fila |

Serve para pipelines e geração de manifests lerem os valores sem acessar o tfstate.

## Pontos de atenção

**Tags de discovery.** O Karpenter descobre subnets e security groups por tag, não por ID. As subnets privadas e o security group do cluster precisam de `karpenter.sh/discovery = <cluster_name>` — isso é responsabilidade dos módulos `vpc` e `eks`, não deste.

**Node group de baseline.** O controller precisa de um nó para rodar antes de conseguir provisionar qualquer outro. Mantenha ao menos um managed node group pequeno no cluster.

**Policy inline, não managed.** A policy do controller é grande (~5,7 KB sem espaços, antes do template expandir os ARNs). Como *managed policy* o limite é 6.144 caracteres — folga apertada demais. Inline em role o limite é 10.240, então é lá que ela vai.

**Destroy.** Nós provisionados pelo Karpenter não estão no state. Remova os `NodePool` antes do `terraform destroy`, senão as instâncias ficam órfãs e seguram a VPC.

## Requisitos

| Nome      | Versão   |
|-----------|----------|
| terraform | >= 1.5   |
| aws       | >= 5.40  |

## Variáveis de entrada

| Nome | Descrição | Tipo | Padrão | Obrigatória |
|------|-----------|------|--------|:-----------:|
| `cluster_name` | Nome do cluster EKS. | `string` | — | sim |
| `oidc_provider_arn` | ARN do OIDC provider (output do módulo eks). | `string` | — | sim |
| `oidc_provider_url` | URL do issuer OIDC (output do módulo eks). | `string` | — | sim |
| `region` | Região usada na policy do controller (null = a do provider). | `string` | `null` | não |
| `namespace` | Namespace do controller. | `string` | `"kube-system"` | não |
| `service_account_name` | Service account do controller. | `string` | `"karpenter"` | não |
| `controller_role_name` | Nome da role do controller (null = padrão). | `string` | `null` | não |
| `node_role_name` | Nome da role dos nós (null = padrão). | `string` | `null` | não |
| `interruption_queue_name` | Nome da fila (null = padrão). | `string` | `null` | não |
| `node_role_additional_policy_arns` | Managed policies extras para os nós `{ rótulo = arn }`. | `map(string)` | `{}` | não |
| `create_node_access_entry` | Cria o access entry `EC2_LINUX` dos nós. | `bool` | `true` | não |
| `node_role_max_session_duration` | Duração máxima da sessão da role dos nós (s). | `number` | `3600` | não |
| `interruption_queue_retention_seconds` | Retenção das mensagens de interrupção (s). | `number` | `300` | não |
| `create_ssm_parameters` | Publica os valores no Parameter Store. | `bool` | `false` | não |
| `ssm_parameter_prefix` | Prefixo dos parâmetros (null = `/karpenter/<cluster_name>`). | `string` | `null` | não |
| `tags` | Tags aplicadas a todos os recursos. | `map(string)` | `{}` | não |

## Outputs

| Nome | Descrição |
|------|-----------|
| `controller_role_arn` | ARN da IRSA do controller (annotation do service account). |
| `controller_role_name` | Nome da role do controller. |
| `service_account_name` | Service account esperado pela trust policy. |
| `namespace` | Namespace esperado pela trust policy. |
| `node_role_name` | Nome da role dos nós (`spec.role` do EC2NodeClass). |
| `node_role_arn` | ARN da role dos nós. |
| `interruption_queue_name` | Nome da fila (`settings.interruptionQueue`). |
| `interruption_queue_arn` | ARN da fila. |
| `interruption_queue_url` | URL da fila. |
| `ssm_parameter_names` | Parâmetros publicados, quando habilitado. |
| `helm_values` | Mapa com os valores do chart derivados desta infraestrutura. |
