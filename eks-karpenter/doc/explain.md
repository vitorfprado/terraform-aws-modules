# Explicação detalhada — módulo eks-karpenter

Este documento percorre cada arquivo do módulo explicando **o que o código faz e por quê foi escrito assim**.

O Karpenter é um autoscaler que provisiona instâncias EC2 diretamente, sem passar por Auto Scaling Groups. Isso significa que ele precisa de permissões amplas na EC2 e de uma identidade para os nós que ele cria — e é justamente essa fiação AWS que este módulo encapsula. O chart Helm fica de fora, por decisão de desenho (ver [README](../README.md)).

---

## Os dois planos

Antes do código, a decisão que estrutura tudo: o Karpenter tem uma parte AWS e uma parte Kubernetes.

| Plano | O que é | Onde vive |
|---|---|---|
| AWS | IAM role dos nós, IRSA do controller, fila SQS, regras EventBridge, access entry | **este módulo** |
| Kubernetes | chart Helm, `NodePool`, `EC2NodeClass` | fora — Helm CLI, `helm_release` no root, ou GitOps |

Os dois mudam em ritmos diferentes. A API do IAM é estável há anos; o chart do Karpenter quebrou compatibilidade com Kubernetes 1.32 entre versões menores. Juntos no mesmo módulo, você é obrigado a versionar os dois no mesmo ritmo — e quem consome só a parte AWS leva churn de graça.

Além disso, um módulo que só usa o provider `aws` não força o consumidor a configurar `helm`/`kubernetes` apontando para um cluster que pode ainda não existir no primeiro apply. É a diferença entre caber num apply só e obrigar a divisão em dois stages.

---

## `main.tf` — data sources e nomes

```hcl
locals {
  region = coalesce(var.region, data.aws_region.current.region)

  controller_role_name    = coalesce(var.controller_role_name, "${var.cluster_name}-karpenter-controller")
  node_role_name          = coalesce(var.node_role_name, "${var.cluster_name}-karpenter-node")
  interruption_queue_name = coalesce(var.interruption_queue_name, "${var.cluster_name}-karpenter")
}
```

`data.aws_partition` existe para o módulo funcionar fora do particionamento comercial (GovCloud, China), onde os ARNs não começam com `arn:aws:`.

Os `coalesce` implementam a política de **nomes determinísticos**: derivados de `cluster_name`, previsíveis, e sobrescrevíveis. A alternativa idiomática seria `name_prefix`, que gera um sufixo aleatório e dá `create_before_destroy` de graça em substituições. Foi descartada porque o consumidor precisa referenciar esses nomes em manifests (`spec.role` do `EC2NodeClass`, `settings.interruptionQueue` do chart) — e um nome com sufixo aleatório obriga a resolver output de Terraform em tempo de render do YAML.

O custo dessa escolha: se você destruir e recriar o mesmo cluster em sequência rápida, o IAM pode ainda ter a role antiga e devolver `EntityAlreadyExists`.

---

## `iam_node.tf` — identidade das instâncias

```hcl
principals {
  type        = "Service"
  identifiers = ["ec2.${data.aws_partition.current.dns_suffix}"]
}
```

Esta role **não é IRSA**. Quem a assume é o serviço EC2, não um service account via OIDC — por isso ela é um `aws_iam_role` direto e não passa pelo módulo `iam-irsa`. O `dns_suffix` do partition (em vez do literal `ec2.amazonaws.com`) mantém o módulo correto em GovCloud e China.

As quatro managed policies são o mínimo para um nó EKS funcional:

| Policy | Sem ela |
|---|---|
| `AmazonEKSWorkerNodePolicy` | o nó não se registra no cluster |
| `AmazonEKS_CNI_Policy` | os pods não recebem IP |
| `AmazonEC2ContainerRegistryReadOnly` | nenhuma imagem do ECR sobe |
| `AmazonSSMManagedInstanceCore` | sem acesso via Session Manager |

`node_role_additional_policy_arns` é um `map(string)` e não `list`. O motivo é o mesmo do módulo `iam-irsa`: o `for_each` itera sobre as **chaves** (rótulos estáticos que o consumidor escolhe), então o **valor** pode ser um ARN *known-after-apply* — uma policy criada no mesmo apply. Com `toset(list)`, o plan quebraria.

### O access entry

```hcl
resource "aws_eks_access_entry" "node" {
  type = "EC2_LINUX"
}
```

Autenticação e autorização são coisas separadas no EKS. A role dá ao nó um jeito de se identificar na API do cluster; o access entry é o que diz que aquela identidade pode agir como nó. Sem ele o nó sobe, aparece no cluster e fica preso em `NotReady`. É o modo moderno de fazer o que antes era uma entrada no ConfigMap `aws-auth`.

---

## `iam_controller.tf` — IRSA via composição

```hcl
module "controller_role" {
  source = "../iam-irsa"
  ...
}
```

Duas decisões aqui.

**Compor em vez de repetir.** A trust policy IRSA — federar ao OIDC provider, fixar `aud` em `sts.amazonaws.com`, restringir `sub` ao service account — é exatamente o que o módulo `iam-irsa` já faz, e faz melhor (com suporte a wildcard de SA). Escrevê-la de novo aqui seria a terceira cópia da mesma lógica na biblioteca.

**Caminho relativo, não URL git.** `source = "../iam-irsa"` resolve dentro do mesmo repositório e da mesma ref. Se fosse `github.com/...//iam-irsa?ref=main`, alguém que pinasse este módulo em `v1.0.0` receberia um `iam-irsa` de `main` — e a versão prometida seria mentira. Caminho relativo é o que torna a tag um conjunto coerente.

### Inline e não managed policy

```hcl
inline_policies = {
  controller = templatefile(...)
}
```

O documento do Karpenter tem ~5,7 KB sem espaços **antes** do template expandir. Depois da substituição, o ARN da role dos nós e o da fila crescem bastante (de `${node_role_arn}`, 16 caracteres, para ~58).

Os limites do IAM, ambos contados **sem espaços em branco**:

| Tipo | Limite |
|---|---|
| Managed policy | 6.144 |
| Inline em role | 10.240 |

Como managed, a policy passaria com menos de 10% de folga — e qualquer statement novo no upstream estouraria. Inline dá margem confortável. O efeito colateral é bem-vindo: uma policy inline não pode ser anexada acidentalmente a outra role.

### O template

`policies/karpenter_controller_iam_policy.json.tftpl` é a policy publicada pelo upstream, mantida verbatim salvo pelas interpolações. Ela recebe o ARN da fila e o da role dos nós, que são *known-after-apply* — e é por isso que `inline_policies` do `iam-irsa` é um map: a chave (`controller`) é estática e conhecida no plan, o valor pode ser computado.

Repare que a policy é escopada por tag (`aws:ResourceTag/kubernetes.io/cluster/<cluster_name>`), não por ARN. É assim que o Karpenter consegue permissão ampla na EC2 sem virar `ec2:*` irrestrito: ele só age sobre recursos marcados como pertencentes àquele cluster.

---

## `interruption.tf` — a fila e o EventBridge

Sem tratamento de interrupção, uma instância spot recolhida derruba os pods sem aviso. O fluxo é: a AWS emite o evento → o EventBridge o encaminha para a fila → o controller consome e drena o nó antes de a instância sumir.

```hcl
resource "aws_sqs_queue" "interruption" {
  message_retention_seconds = 300
  sqs_managed_sse_enabled   = true
}
```

Os 300 segundos não são arbitrários: o aviso de interrupção de spot dá **dois minutos**. Uma mensagem mais velha que isso já não é acionável — reter por mais tempo só faria o controller processar eventos de nós que já morreram.

A queue policy permite `sqs:SendMessage` a `events.amazonaws.com` (o EventBridge) e `sqs.amazonaws.com`. É o lado do recurso; o lado da identidade (o controller poder ler) vem do statement `AllowInterruptionQueueActions` da policy do controller.

### As quatro regras

```hcl
locals {
  interruption_events = {
    spot_interruption     = { source = "aws.ec2",    detail_type = "EC2 Spot Instance Interruption Warning" }
    rebalance             = { source = "aws.ec2",    detail_type = "EC2 Instance Rebalance Recommendation" }
    instance_state_change = { source = "aws.ec2",    detail_type = "EC2 Instance State-change Notification" }
    scheduled_change      = { source = "aws.health", detail_type = "AWS Health Event" }
  }
}
```

Um map de locals com `for_each` em vez de quatro blocos repetidos. Cobrem situações diferentes: spot sendo recolhido, spot em risco (rebalance, chega antes do aviso formal), mudança de estado de qualquer instância, e manutenção programada pela AWS.

Aqui as regras usam `name_prefix`, não nome fixo — ao contrário das roles. A diferença é intencional: nenhum manifest referencia o nome de uma regra do EventBridge, então não há razão para abrir mão do `create_before_destroy`.

---

## `ssm.tf` — a ponte para a camada de manifests

```hcl
ssm_parameters = var.create_ssm_parameters ? { ... } : {}
```

Três valores atravessam a fronteira entre infra e cluster: o ARN da role do controller, o nome da role dos nós e o nome da fila. Publicá-los no Parameter Store permite que pipelines e geração de manifests os leiam **sem acessar o tfstate** — que costuma estar num bucket com permissão restrita, e cujo formato é detalhe interno do Terraform.

O `for_each` sobre um map ternário (e não `count` em cada recurso) mantém os endereços no state estáveis e legíveis: `aws_ssm_parameter.karpenter["node-role-name"]`.

Isso é publicação, não resolução dinâmica: o Parameter Store guarda os valores para consulta, mas como os nomes já são determinísticos, nada precisa resolvê-los em tempo de render.

---

## `outputs.tf` — incluindo `helm_values`

Além dos outputs individuais, o módulo expõe:

```hcl
output "helm_values" {
  value = {
    settings       = { clusterName = ..., interruptionQueue = ... }
    serviceAccount = { name = ..., annotations = { "eks.amazonaws.com/role-arn" = ... } }
  }
}
```

É açúcar sintático com propósito: o consumidor faz `terraform output -json helm_values > values.yaml` e tem o arquivo pronto, sem precisar saber quais chaves do chart correspondem a quais outputs. Mantém o módulo fora do negócio de instalar charts, mas sem empurrar para o consumidor a tarefa de descobrir o mapeamento.

`service_account_name` e `namespace` também são outputs, ainda que sejam apenas eco das variáveis de entrada. O motivo é contratual: a trust policy da role foi construída sobre esses dois valores, e se a instalação do chart usar outros, o pod recebe `AccessDenied` sem explicação óbvia. Expô-los deixa o acoplamento visível.
