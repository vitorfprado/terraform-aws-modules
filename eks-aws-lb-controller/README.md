# Módulo Terraform – EKS AWS Load Balancer Controller (infraestrutura AWS)

Cria a IAM role (IRSA) do [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/) com a policy oficial do projeto, para um cluster EKS existente.

O módulo **não instala o chart Helm** e **não exige os providers `helm`/`kubernetes`** — só `aws`. A instalação fica com quem consome (Helm CLI, `helm_release` no root, ou GitOps), usando os outputs.

## Recursos criados

| Recurso | Papel |
|---|---|
| `module.role` (via [`../iam-irsa`](../iam-irsa)) | IRSA do controller, com a policy do projeto inline |
| `aws_ssm_parameter` | Publicação do ARN da role para a camada de manifests (opcional) |

A policy fica em [`policies/aws_lbc_iam_policy.json`](./policies/aws_lbc_iam_policy.json), mantida **verbatim** como publicada pelo upstream — assim o diff é direto quando o projeto atualizar o documento.

## Uso

```hcl
module "lb_controller" {
  source = "github.com/fiap-tech-challenge-devops/terraform-aws-modules//eks-aws-lb-controller?ref=v1.0.0"

  cluster_name      = module.eks.cluster_name
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url
  vpc_id            = module.vpc.vpc_id

  create_ssm_parameters = true

  tags = {
    Environment = "prod"
  }
}
```

Um exemplo completo e copiável (VPC + EKS + role) está em [`example/`](./example).

## Instalando o chart

```bash
terraform output -json helm_values | jq . > lbc-values.yaml

helm repo add eks https://aws.github.io/eks-charts
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  --version "1.8.1" --namespace kube-system -f lbc-values.yaml
```

O output `helm_values` já traz `clusterName`, `vpcId`, `region` e o bloco `serviceAccount` com a annotation da role.

> **A versão do chart é escolha sua** — o módulo não tem opinião nem default.

## Pontos de atenção

**Tags de discovery de subnet.** O controller descobre onde criar o load balancer pelas tags das subnets, não por parâmetro. Sem elas o `Ingress` fica pendente com `unable to discover subnets`:

| Tag | Subnets |
|---|---|
| `kubernetes.io/role/elb = 1` | públicas (ALB internet-facing) |
| `kubernetes.io/role/internal-elb = 1` | privadas (ALB interno) |

Isso é responsabilidade do módulo `vpc`, não deste.

**Webhook de mutação de Service.** O chart instala um webhook que intercepta **todo** `Service` do cluster. Antes dos pods do controller ficarem prontos, ele quebra a criação de Services de outros charts com `no endpoints available for service aws-load-balancer-webhook-service`. Se você só usa `Ingress` e nunca `Service type=LoadBalancer`, desligue com `enableServiceMutatorWebhook: false` nos values.

**Destroy.** Os ALBs criados pelo controller não estão no state do Terraform. Remova os `Ingress` antes do `terraform destroy`, senão os load balancers ficam órfãos e seguram a VPC.

**Nome determinístico.** A role usa `<cluster_name>-aws-lb-controller` (sobrescrevível por `role_name`), não `name_prefix`, para que os manifests possam referenciá-la como string estável.

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
| `vpc_id` | ID da VPC do cluster. | `string` | — | sim |
| `region` | Região (null = a do provider). | `string` | `null` | não |
| `namespace` | Namespace do controller. | `string` | `"kube-system"` | não |
| `service_account_name` | Service account do controller. | `string` | `"aws-load-balancer-controller"` | não |
| `role_name` | Nome da role (null = `<cluster_name>-aws-lb-controller`). | `string` | `null` | não |
| `create_ssm_parameters` | Publica o ARN da role no Parameter Store. | `bool` | `false` | não |
| `ssm_parameter_prefix` | Prefixo dos parâmetros (null = `/aws-lb-controller/<cluster_name>`). | `string` | `null` | não |
| `tags` | Tags aplicadas a todos os recursos. | `map(string)` | `{}` | não |

## Outputs

| Nome | Descrição |
|------|-----------|
| `role_arn` | ARN da role (annotation do service account). |
| `role_name` | Nome da role. |
| `service_account_name` | Service account esperado pela trust policy. |
| `namespace` | Namespace esperado pela trust policy. |
| `ssm_parameter_names` | Parâmetros publicados, quando habilitado. |
| `helm_values` | Mapa com os valores do chart derivados desta infraestrutura. |
