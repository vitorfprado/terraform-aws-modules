# Módulo Terraform – Amazon EKS

Provisiona um cluster Amazon EKS completo e pronto para produção: control plane, IAM roles, managed node groups, add-ons gerenciados, OIDC provider para IRSA, criptografia de secrets via KMS, logs no CloudWatch e access entries (modelo de acesso por API, sucessor do `aws-auth`).

O módulo não cria a rede. Informe uma VPC e subnets existentes — assim ele se integra facilmente a um módulo de VPC próprio ou da comunidade.

## Recursos criados

- `aws_eks_cluster` – control plane com logging e (opcional) criptografia de secrets
- `aws_iam_role` – role do control plane e role compartilhada dos node groups
- `aws_eks_node_group` – um managed node group por entrada no mapa `node_groups`
- `aws_eks_addon` – add-ons gerenciados (coredns, kube-proxy, vpc-cni, ...)
- `aws_iam_openid_connect_provider` – OIDC provider para IRSA (opcional)
- `aws_kms_key` / `aws_kms_alias` – criptografia de secrets (opcional)
- `aws_cloudwatch_log_group` – logs do control plane
- `aws_eks_access_entry` / `aws_eks_access_policy_association` – controle de acesso

## Uso

```hcl
module "eks" {
  source = "github.com/<org>/terraform-aws-modules//eks"

  cluster_name    = "producao"
  cluster_version = "1.32"

  vpc_id     = "vpc-0123456789abcdef0"
  subnet_ids = ["subnet-aaa", "subnet-bbb", "subnet-ccc"]

  node_groups = {
    general = {
      instance_types = ["t3.large"]
      desired_size   = 3
      min_size       = 2
      max_size       = 6
    }
  }

  cluster_addons = {
    coredns    = {}
    kube-proxy = {}
    vpc-cni    = {}
  }

  tags = {
    Environment = "producao"
  }
}
```

Um exemplo completo, copiável e pronto para uso está em [`example/`](./example).

## Requisitos

| Nome      | Versão   |
|-----------|----------|
| terraform | >= 1.5   |
| aws       | >= 5.40  |
| tls       | >= 4.0   |

## Variáveis de entrada

| Nome | Descrição | Tipo | Padrão | Obrigatória |
|------|-----------|------|--------|:-----------:|
| `cluster_name` | Nome do cluster EKS e prefixo dos recursos. | `string` | — | sim |
| `vpc_id` | ID da VPC onde o cluster será provisionado. | `string` | — | sim |
| `subnet_ids` | Subnets dos node groups e, por padrão, do control plane. | `list(string)` | — | sim |
| `cluster_version` | Versão do Kubernetes do control plane. | `string` | `"1.32"` | não |
| `control_plane_subnet_ids` | Subnets dedicadas às ENIs do control plane. | `list(string)` | `[]` | não |
| `endpoint_private_access` | Habilita acesso privado ao endpoint da API. | `bool` | `true` | não |
| `endpoint_public_access` | Habilita acesso público ao endpoint da API. | `bool` | `false` | não |
| `public_access_cidrs` | CIDRs autorizados no endpoint público. | `list(string)` | `["0.0.0.0/0"]` | não |
| `additional_security_group_ids` | Security groups extras no control plane. | `list(string)` | `[]` | não |
| `cluster_enabled_log_types` | Tipos de log do control plane no CloudWatch. | `list(string)` | `["api","audit","authenticator"]` | não |
| `cloudwatch_log_retention_in_days` | Retenção dos logs do control plane. | `number` | `90` | não |
| `cloudwatch_log_kms_key_id` | KMS key para criptografar o log group. | `string` | `null` | não |
| `authentication_mode` | `API`, `API_AND_CONFIG_MAP` ou `CONFIG_MAP`. | `string` | `"API_AND_CONFIG_MAP"` | não |
| `bootstrap_cluster_creator_admin_permissions` | Concede admin ao criador do cluster. | `bool` | `true` | não |
| `create_cluster_iam_role` | Cria a role do control plane. | `bool` | `true` | não |
| `cluster_iam_role_arn` | Role existente do control plane. | `string` | `null` | não |
| `create_node_iam_role` | Cria a role compartilhada dos nodes. | `bool` | `true` | não |
| `node_iam_role_arn` | Role existente dos nodes. | `string` | `null` | não |
| `node_iam_role_additional_policies` | Políticas IAM extras para os nodes. | `map(string)` | `{}` | não |
| `enable_irsa` | Cria o OIDC provider (IRSA). | `bool` | `true` | não |
| `create_kms_key` | Cria KMS key para criptografar secrets. | `bool` | `true` | não |
| `kms_key_arn` | KMS key existente para os secrets. | `string` | `null` | não |
| `kms_key_deletion_window_in_days` | Janela de exclusão da KMS key. | `number` | `30` | não |
| `node_groups` | Mapa de managed node groups. | `map(object)` | `{}` | não |
| `cluster_addons` | Mapa de EKS add-ons gerenciados. | `map(object)` | `{}` | não |
| `access_entries` | Mapa de access entries (acesso por API). | `map(object)` | `{}` | não |
| `tags` | Tags aplicadas a todos os recursos. | `map(string)` | `{}` | não |

### Estrutura de `node_groups`

```hcl
node_groups = {
  general = {
    instance_types             = ["t3.medium"]          # padrão ["t3.medium"]
    capacity_type              = "ON_DEMAND"             # ON_DEMAND ou SPOT
    ami_type                   = "AL2023_x86_64_STANDARD"
    disk_size                  = 20
    desired_size               = 2
    min_size                   = 1
    max_size                   = 3
    subnet_ids                 = []                       # vazio = usa var.subnet_ids
    labels                     = { role = "general" }
    max_unavailable            = null                     # ou max_unavailable_percentage
    max_unavailable_percentage = null
    taints                     = [{ key = "dedicated", value = "gpu", effect = "NO_SCHEDULE" }]
    tags                       = {}
  }
}
```

> O `desired_size` é ignorado em atualizações (`ignore_changes`) para não conflitar com o Cluster Autoscaler / Karpenter.

### Estrutura de `cluster_addons`

```hcl
cluster_addons = {
  vpc-cni = {
    version                  = "v1.18.1-eksbuild.3"      # opcional, fixa a versão
    service_account_role_arn = module.vpc_cni_irsa.arn   # opcional (IRSA)
    configuration_values     = jsonencode({})            # opcional
    preserve                 = true
  }
}
```

### Estrutura de `access_entries`

```hcl
access_entries = {
  admin = {
    principal_arn = "arn:aws:iam::123456789012:role/eks-admin"
    policy_associations = {
      cluster_admin = {
        policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
        scope_type = "cluster"                            # ou "namespace" + namespaces = [...]
      }
    }
  }
}
```

## Outputs

| Nome | Descrição |
|------|-----------|
| `cluster_name` | Nome do cluster. |
| `cluster_arn` | ARN do cluster. |
| `cluster_endpoint` | Endpoint da API do Kubernetes. |
| `cluster_version` | Versão do Kubernetes em execução. |
| `cluster_certificate_authority_data` | Certificado da CA (base64) para o kubeconfig. |
| `cluster_security_group_id` | Security group gerenciado pelo EKS. |
| `cluster_iam_role_arn` | ARN da role do control plane. |
| `node_iam_role_arn` | ARN da role dos node groups. |
| `node_iam_role_name` | Nome da role dos node groups. |
| `oidc_provider_arn` | ARN do OIDC provider (para IRSA). |
| `oidc_provider_url` | URL do issuer OIDC (sem `https://`). |
| `kms_key_arn` | ARN da KMS key dos secrets. |
| `cloudwatch_log_group_name` | Log group do control plane. |
| `node_groups` | Atributos dos node groups criados. |
| `cluster_addons` | Atributos dos add-ons gerenciados. |

## Interligando com outros módulos

Os outputs foram pensados para encadear módulos. Exemplo de uma role IRSA usando o OIDC provider exposto:

```hcl
data "aws_iam_policy_document" "irsa_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${module.eks.oidc_provider_url}:sub"
      values   = ["system:serviceaccount:kube-system:external-dns"]
    }
  }
}
```

E configurando o provider `kubernetes`/`helm` a partir dos outputs do cluster:

```hcl
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}
```
