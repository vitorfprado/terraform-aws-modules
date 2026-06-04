# Explicação detalhada — módulo EKS

Este documento percorre cada arquivo do módulo explicando **o que o código faz e por quê foi escrito assim**. Os arquivos são apresentados na ordem de dependência — do que precisa existir antes para o que é criado depois.

---

## `main.tf` — locals e cluster

### `data "aws_partition"`

```hcl
data "aws_partition" "current" {}
```

Resolve em qual partição AWS o provider está autenticado: `aws` (comercial), `aws-cn` (China) ou `aws-us-gov` (GovCloud). Usado para montar ARNs de políticas gerenciadas sem hardcodar `arn:aws:...`, o que quebraria em regiões não-comerciais.

### locals

```hcl
locals {
  cluster_role_arn         = var.create_cluster_iam_role ? aws_iam_role.cluster[0].arn : var.cluster_iam_role_arn
  control_plane_subnet_ids = distinct(concat(var.subnet_ids, var.control_plane_subnet_ids))

  create_node_role = var.create_node_iam_role && length(var.node_groups) > 0
  node_role_arn    = var.create_node_iam_role ? try(aws_iam_role.node[0].arn, null) : var.node_iam_role_arn

  enable_encryption  = var.create_kms_key || var.kms_key_arn != null
  encryption_key_arn = var.create_kms_key ? aws_kms_key.secrets[0].arn : var.kms_key_arn

  oidc_provider_url   = replace(aws_eks_cluster.main.identity[0].oidc[0].issuer, "https://", "")
  create_ebs_csi_irsa = var.enable_ebs_csi_driver && var.enable_irsa

  access_policy_associations = merge([...])
}
```

Os locals centralizam as decisões condicionais do módulo para que os recursos não precisem repetir a mesma lógica:

**`cluster_role_arn`** — o módulo pode criar a role do control plane ou receber uma existente. Este local resolve qual usar, evitando que `aws_eks_cluster.main` precise de um `if/else` inline.

**`control_plane_subnet_ids`** — o EKS aceita subnets diferentes para as ENIs do control plane e para os nodes. O `distinct(concat(...))` mescla as duas listas eliminando duplicatas: se o consumidor não passar `control_plane_subnet_ids`, as ENIs vão nas mesmas subnets dos nodes.

**`create_node_role`** — a role dos nodes só deve ser criada se `var.create_node_iam_role` estiver habilitado **e** houver ao menos um node group definido. Criar uma role sem nenhum node para usá-la seria desperdício.

**`enable_encryption` / `encryption_key_arn`** — dois caminhos possíveis: criar uma KMS key nova ou usar uma existente. Se nenhum dos dois for configurado, `enable_encryption` é `false` e o bloco `encryption_config` não é gerado.

**`oidc_provider_url`** — o issuer OIDC que a AWS retorna inclui o prefixo `https://`, mas políticas de trust IAM exigem a URL sem ele. O `replace` remove o prefixo uma vez, aqui, para que todos os recursos que precisam da URL (IRSA do EBS CSI, etc.) não precisem repetir a mesma transformação.

**`create_ebs_csi_irsa`** — combinação de duas flags. O addon EBS CSI precisa de IRSA para funcionar; se o OIDC provider não for criado (`enable_irsa = false`), não faz sentido criar a role IRSA do driver.

**`access_policy_associations`** — a estrutura de `access_entries` no `variables.tf` tem dois níveis: o entry (principal) e as policy associations (políticas daquele principal). Para criar os recursos do segundo nível com `for_each`, é preciso um mapa plano. Este local achata a estrutura aninhada:

```
{ "admin/cluster_admin" => { principal_arn = "...", policy_arn = "..." } }
```

A chave `"${entry_key}/${assoc_key}"` garante unicidade mesmo quando dois principals têm associações com a mesma chave interna.

### Log group do control plane

```hcl
resource "aws_cloudwatch_log_group" "control_plane" {
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = var.cloudwatch_log_retention_in_days
  ...
}
```

O EKS cria o log group automaticamente se ele não existir, mas sem retenção definida — os logs ficam para sempre e o custo cresce indefinidamente. Criar o grupo explicitamente antes do cluster garante que a retenção seja configurada desde o início. O `depends_on` em `aws_eks_cluster.main` aponta para este recurso exatamente por isso.

O nome `/aws/eks/<cluster>/cluster` é o padrão que o EKS usa. Criar com o nome errado não adiantaria nada.

### Cluster

```hcl
resource "aws_eks_cluster" "main" {
  ...
  access_config {
    authentication_mode                         = var.authentication_mode
    bootstrap_cluster_creator_admin_permissions = var.bootstrap_cluster_creator_admin_permissions
  }
  ...
  dynamic "encryption_config" {
    for_each = local.enable_encryption ? [1] : []
    content {
      resources = ["secrets"]
      provider { key_arn = local.encryption_key_arn }
    }
  }
}
```

**`access_config`** — define o modelo de autenticação do cluster. O padrão `API_AND_CONFIG_MAP` mantém compatibilidade com o ConfigMap `aws-auth` (modelo legado) ao mesmo tempo que habilita o novo modelo de Access Entries via API. Isso evita quebrar clusters já existentes que ainda usam o ConfigMap. `bootstrap_cluster_creator_admin_permissions = true` garante que quem criou o cluster tenha acesso de admin automaticamente, sem precisar criar um access entry manualmente logo após o apply.

**`dynamic "encryption_config"`** — blocos dinâmicos permitem gerar um bloco de configuração condicionalmente. O `for_each = local.enable_encryption ? [1] : []` é um padrão Terraform: quando a lista tem um elemento, o bloco é gerado; quando está vazia, não é. Sem isso seria necessário duplicar o recurso inteiro com `count`.

O parâmetro `resources = ["secrets"]` especifica que apenas os objetos do tipo Secret do Kubernetes são criptografados com a KMS key (envelope encryption). Outros objetos (Pods, ConfigMaps) usam a criptografia padrão do etcd.

---

## `iam.tf` — roles do control plane e dos nodes

### Role do control plane

```hcl
data "aws_iam_policy_document" "cluster_assume" {
  statement {
    actions    = ["sts:AssumeRole"]
    principals { type = "Service"; identifiers = ["eks.amazonaws.com"] }
  }
}

resource "aws_iam_role" "cluster" { ... }

resource "aws_iam_role_policy_attachment" "cluster" {
  for_each = toset([
    "...AmazonEKSClusterPolicy",
    "...AmazonEKSVPCResourceController",
  ])
  ...
}
```

O EKS exige uma role para operar o control plane em seu nome. A trust policy usa `aws_iam_policy_document` (em vez de JSON inline) para que o Terraform gerencie o estado do documento e detecte mudanças.

`for_each = toset([...])` em vez de dois recursos separados é uma questão de manutenibilidade: para adicionar ou remover uma política, basta editar a lista sem criar ou deletar blocos de recurso.

**`AmazonEKSClusterPolicy`** — permissões básicas do control plane (gerenciar ENIs, security groups, descrever instâncias EC2, etc.).

**`AmazonEKSVPCResourceController`** — necessária para o recurso de Security Groups for Pods. Sem ela o EKS não consegue gerenciar interfaces de rede secundárias nos nodes.

### Role dos nodes

```hcl
resource "aws_iam_role" "node" {
  count = local.create_node_role ? 1 : 0
  ...
}

resource "aws_iam_role_policy_attachment" "node" {
  for_each = local.create_node_role ? toset([
    "...AmazonEKSWorkerNodePolicy",
    "...AmazonEKS_CNI_Policy",
    "...AmazonEC2ContainerRegistryReadOnly",
    "...AmazonSSMManagedInstanceCore",
  ]) : []
  ...
}
```

Os nodes (instâncias EC2) também precisam de uma role para se comunicar com o control plane e com outros serviços AWS.

**`AmazonEKSWorkerNodePolicy`** — permite que o node se registre no cluster e reporte seu status.

**`AmazonEKS_CNI_Policy`** — necessária para o plugin `vpc-cni` gerenciar IPs e interfaces de rede nas instâncias. Sem ela, pods não recebem endereços IP da VPC.

**`AmazonEC2ContainerRegistryReadOnly`** — permite pull de imagens do ECR sem expor credenciais nos pods.

**`AmazonSSMManagedInstanceCore`** — habilita o SSM Session Manager, permitindo acesso ao shell dos nodes sem precisar de SSH ou bastions.

**`node_additional`** — permite injetar políticas extras sem modificar o módulo, por exemplo para dar acesso a buckets S3 ou parâmetros do SSM que workloads específicos precisam.

---

## `kms.tf` — criptografia de secrets

```hcl
resource "aws_kms_key" "secrets" {
  count                   = var.create_kms_key ? 1 : 0
  enable_key_rotation     = true
  deletion_window_in_days = var.kms_key_deletion_window_in_days
  ...
}

resource "aws_kms_alias" "secrets" {
  count         = var.create_kms_key ? 1 : 0
  name          = "alias/eks/${var.cluster_name}"
  target_key_id = aws_kms_key.secrets[0].key_id
}
```

**Por que criptografar secrets?** Por padrão, os objetos Secret do Kubernetes são armazenados em texto base64 no etcd — base64 não é criptografia, qualquer pessoa com acesso ao etcd pode ler. A envelope encryption usa uma KMS key para criptografar a chave de dados que o etcd usa, adicionando uma camada gerenciada pela AWS.

**`enable_key_rotation = true`** — boas práticas de segurança exigem rotação periódica das chaves. A AWS rotaciona automaticamente o material criptográfico a cada ano sem impacto nas operações.

**`deletion_window_in_days`** — ao deletar uma KMS key, a AWS entra em um período de espera antes da exclusão definitiva. Durante esse tempo você pode cancelar. O default de 30 dias é o máximo disponível e é recomendado para ambientes de produção, pois dados criptografados com a key se tornam irrecuperáveis após a exclusão permanente.

O **alias** (`alias/eks/<cluster>`) é um nome amigável para a key. Sem ele, referências futuras exigiriam o ID hexadecimal completo.

---

## `irsa.tf` — OIDC provider para IRSA

```hcl
data "tls_certificate" "oidc" {
  count = var.enable_irsa ? 1 : 0
  url   = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "oidc" {
  count           = var.enable_irsa ? 1 : 0
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.oidc[0].certificates[0].sha1_fingerprint]
  ...
}
```

**IRSA (IAM Roles for Service Accounts)** é o mecanismo que permite associar uma role IAM a um service account do Kubernetes. Sem ele, pods que precisam chamar APIs AWS (S3, Secrets Manager, SQS, etc.) precisariam de credenciais hardcodadas ou da role do node inteiro — o que viola o princípio de menor privilégio.

**Como funciona:** quando um pod usa um service account anotado com `eks.amazonaws.com/role-arn`, o EKS injeta um token OIDC assinado. O pod usa esse token para chamar o STS (`AssumeRoleWithWebIdentity`) e receber credenciais temporárias da role específica.

**`data "tls_certificate"`** — o OIDC provider da AWS precisa de um thumbprint do certificado TLS do servidor OIDC do cluster para verificar tokens. O provider `tls` busca esse certificado automaticamente, evitando que ele precise ser informado manualmente.

**`client_id_list = ["sts.amazonaws.com"]`** — especifica quem pode consumir tokens emitidos por este issuer. O STS da AWS é o único cliente relevante para IRSA.

---

## `node_groups.tf` — managed node groups

```hcl
resource "aws_eks_node_group" "managed" {
  for_each = var.node_groups

  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.cluster_name}-${each.key}"
  ...

  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }

  depends_on = [
    aws_iam_role_policy_attachment.node,
    aws_iam_role_policy_attachment.node_additional,
  ]
}
```

**`for_each = var.node_groups`** — um recurso por entrada no mapa. A chave do mapa vira parte do nome do node group (`demo-general`, `demo-spot`). Adicionar ou remover node groups é só editar o mapa.

**`subnet_ids = length(each.value.subnet_ids) > 0 ? each.value.subnet_ids : var.subnet_ids`** — permite que cada node group use subnets diferentes das subnets padrão do cluster. Útil para workloads GPU que precisam de subnets específicas com instâncias disponíveis.

**`dynamic "taint"`** — taints são restrições que impedem pods sem a tolerância correspondente de rodar no node group. Por exemplo, o node group `spot` tem taint `spot=true:NoSchedule`: apenas pods que explicitamente toleram interrupções de spot são agendados lá.

**`dynamic "update_config"`** — controla quantos nodes podem ficar indisponíveis simultaneamente durante um rolling update. Só é gerado se `max_unavailable` ou `max_unavailable_percentage` for informado; sem isso, o EKS usa o default dele.

**`ignore_changes = [scaling_config[0].desired_size]`** — esta é a decisão mais importante do arquivo. Se `desired_size` fosse gerenciado pelo Terraform, qualquer `terraform apply` após um Cluster Autoscaler ou Karpenter terem ajustado a quantidade de nodes reverteria a escala para o valor do código. O `ignore_changes` delega o controle do `desired_size` para o autoscaler em runtime, enquanto o Terraform continua gerenciando `min_size` e `max_size`.

**`depends_on` nas policy attachments** — o EKS não aceita registrar um node cuja role ainda não tem as políticas necessárias. O Terraform não consegue inferir essa dependência automaticamente porque a relação é entre um `for_each` (attachments) e outro `for_each` (node groups), então ela precisa ser declarada explicitamente.

---

## `addons.tf` — add-ons gerenciados

```hcl
resource "aws_eks_addon" "managed" {
  for_each = var.cluster_addons

  preserve                    = each.value.preserve
  resolve_conflicts_on_create = each.value.resolve_conflicts_on_create
  resolve_conflicts_on_update = each.value.resolve_conflicts_on_update

  depends_on = [aws_eks_node_group.managed]
}
```

**Add-ons gerenciados** são componentes do cluster cuja instalação e atualização são gerenciadas pela AWS (em vez de Helm charts manuais). A AWS mantém versões compatíveis com cada versão do Kubernetes.

**`preserve = true`** (padrão) — ao remover o add-on do Terraform, o recurso é deletado do state mas os objetos Kubernetes instalados por ele (Deployment, ConfigMap, etc.) permanecem no cluster. Isso evita interrupções acidentais de componentes críticos como o `coredns`.

**`resolve_conflicts_on_create/update = "OVERWRITE"`** — quando o add-on gerenciado encontra configurações customizadas (feitas manualmente no cluster), sobrescreve com os valores padrão. A alternativa `PRESERVE` manteria as customizações mas pode impedir atualizações. Para ambientes gerenciados 100% por código, `OVERWRITE` é a escolha correta.

**`depends_on = [aws_eks_node_group.managed]`** — alguns add-ons (especialmente `coredns`) precisam que exista ao menos um node disponível para serem instalados. Sem este `depends_on`, o EKS tentaria instalar os add-ons enquanto ainda não há nodes, resultando em erro.

---

## `access.tf` — controle de acesso ao cluster

```hcl
resource "aws_eks_access_entry" "principals" {
  for_each      = var.access_entries
  principal_arn = each.value.principal_arn
  type          = each.value.type
  ...
}

resource "aws_eks_access_policy_association" "principals" {
  for_each = local.access_policy_associations
  ...
  access_scope {
    type       = each.value.scope_type
    namespaces = each.value.scope_type == "namespace" ? each.value.namespaces : null
  }

  depends_on = [aws_eks_access_entry.principals]
}
```

O EKS tem dois modelos de controle de acesso:

- **ConfigMap `aws-auth`** (legado) — um ConfigMap no namespace `kube-system` que mapeia ARNs IAM para grupos/users do Kubernetes. Gerenciado manualmente ou por ferramentas externas.
- **Access Entries via API** (atual) — recursos nativos da AWS que associam roles/users IAM a políticas de acesso do EKS. Mais seguro e auditável porque é gerenciado via IAM e AWS APIs.

Este módulo usa o modelo atual. O `authentication_mode = "API_AND_CONFIG_MAP"` (default) mantém compatibilidade com o legado durante uma migração.

**Access Entry** — registra um principal IAM (role ou user) como identidade reconhecida pelo cluster. O `type = "STANDARD"` é para humanos e workloads externos; `EC2_LINUX` é para roles de nodes EC2 (usado pelo Karpenter).

**Access Policy Association** — define o que aquele principal pode fazer. A separação em dois recursos permite que um principal tenha múltiplas políticas. O `access_scope` restringe a política a um namespace específico (type `namespace`) ou a todo o cluster (type `cluster`).

**`namespaces = ... == "namespace" ? each.value.namespaces : null`** — o argumento `namespaces` só é válido quando `scope_type = "namespace"`. Passá-lo com `scope_type = "cluster"` causaria erro da API. A condicional garante que ele só seja enviado quando fizer sentido.

---

## `ebs_csi.tf` — EBS CSI driver com IRSA

```hcl
data "aws_iam_policy_document" "ebs_csi_assume" {
  count = local.create_ebs_csi_irsa ? 1 : 0

  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals { type = "Federated"; identifiers = [aws_iam_openid_connect_provider.oidc[0].arn] }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider_url}:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider_url}:sub"
      values   = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
    }
  }
}
```

**Por que o EBS CSI precisa de IRSA?** A partir do Kubernetes 1.23 o driver de EBS in-tree foi removido. O CSI driver externo precisa chamar APIs da AWS (`ec2:CreateVolume`, `ec2:AttachVolume`, etc.) em nome do cluster. Sem IRSA, o driver precisaria de credenciais hardcodadas ou da role do node inteiro — o que daria a todos os pods acesso para criar volumes EBS.

**Trust policy com duas condições `StringEquals`:**

- `:aud = sts.amazonaws.com` — restringe o token ao serviço STS. Sem isso, tokens emitidos para outros propósitos poderiam assumir a role.
- `:sub = system:serviceaccount:kube-system:ebs-csi-controller-sa` — amarra a role exatamente ao service account do controller do EBS CSI. Sem isso, qualquer pod do cluster poderia assumir a role usando IRSA.

```hcl
resource "aws_eks_addon" "ebs_csi" {
  ...
  service_account_role_arn = one(aws_iam_role.ebs_csi[*].arn)
  ...
  lifecycle {
    precondition {
      condition     = var.enable_irsa
      error_message = "enable_ebs_csi_driver requer enable_irsa = true..."
    }
  }
}
```

**`one(...)`** — função que retorna o único elemento de uma lista, ou `null` se a lista estiver vazia. É mais segura que `[0]` porque não explode se `create_ebs_csi_irsa` for `false` e a lista estiver vazia — simplesmente passa `null` para o addon, que então não terá role IRSA (comportamento válido se o usuário escolheu não criar a role).

**`precondition`** — valida um pré-requisito antes do apply. Se `enable_ebs_csi_driver = true` mas `enable_irsa = false`, o plan falha com a mensagem de erro em vez de criar o addon sem role e fazê-lo falhar silenciosamente em runtime. Falhar rápido com uma mensagem clara é sempre melhor.

---

## Ordem de criação dos recursos

O gráfico de dependências real do módulo durante um `terraform apply` do zero:

```
aws_partition (data)
  │
  ├─── aws_kms_key.secrets ──────────────────────────────────────────┐
  │         └── aws_kms_alias.secrets                                 │
  │                                                                   │
  ├─── aws_iam_role.cluster ──┐                                       │
  │         └── attachments   │                                       │
  │                           ▼                                       ▼
  │              aws_cloudwatch_log_group.control_plane
  │                           │
  │                           ▼
  │              aws_eks_cluster.main  ◄──────────────────────────────┘
  │                    │
  │        ┌───────────┼────────────────┐
  │        ▼           ▼                ▼
  │   aws_iam_openid   aws_iam_role.node  + attachments
  │   _connect_        │
  │   provider.oidc    │
  │        │           ▼
  │        │    aws_eks_node_group.managed (um por entrada)
  │        │           │
  │        │    ┌──────┴───────────┐
  │        │    ▼                  ▼
  │        │  aws_eks_addon.managed   aws_eks_addon.ebs_csi
  │        │
  │        └─── aws_iam_role.ebs_csi ──► aws_eks_addon.ebs_csi
  │
  └─── aws_eks_access_entry.principals ──► aws_eks_access_policy_association.principals
```

Recursos sem seta explícita são resolvidos pelo Terraform via referência de atributo (ex.: `aws_eks_cluster.main.name` em `aws_eks_node_group.managed` cria a dependência automaticamente). Os `depends_on` explícitos existem apenas onde essa inferência não é possível.
