# Explicação detalhada — módulo eks-aws-lb-controller

Este documento percorre cada arquivo do módulo explicando **o que o código faz e por quê foi escrito assim**.

O módulo é deliberadamente pequeno: cria uma IAM role IRSA com a policy oficial do AWS Load Balancer Controller. Todo o resto — o chart, o `IngressClass`, os `Ingress` — é plano Kubernetes e fica fora.

---

## Por que isso é um módulo

Um wrapper de `helm_release` não valeria um módulo: são dez linhas que qualquer consumidor escreve mais rápido do que lê a documentação. O que justifica este módulo é a **policy**: 4,8 KB de JSON com dezenas de ações sobre `elasticloadbalancing`, `ec2`, `wafv2`, `shield` e `acm`, escopadas por condição de tag. Ninguém escreve isso do zero, e errar significa um `Ingress` que fica pendente sem mensagem clara.

Guardar esse documento versionado, junto com a trust policy correta, é reuso real.

---

## `main.tf`

```hcl
module "role" {
  source = "../iam-irsa"

  name             = local.role_name
  namespace        = var.namespace
  service_accounts = [var.service_account_name]

  inline_policies = {
    controller = file("${path.module}/policies/aws_lbc_iam_policy.json")
  }
}
```

**Composição em vez de repetição.** A trust policy IRSA já existe no módulo `iam-irsa`. Escrevê-la aqui de novo seria a terceira cópia da mesma lógica na biblioteca — federação ao OIDC, `aud` fixo em `sts.amazonaws.com`, `sub` restrito ao service account.

**Caminho relativo, não URL git.** `../iam-irsa` resolve dentro do mesmo repositório e da mesma ref. Com URL git, alguém que pinasse este módulo em `v1.0.0` receberia um `iam-irsa` de `main` — a tag deixaria de descrever um conjunto coerente.

**`file()` e não `templatefile()`.** Ao contrário do Karpenter, esta policy não tem nada a interpolar: ela é escopada por condição de tag (`elasticloadbalancing:ResourceTag/elbv2.k8s.aws/cluster`), avaliada em runtime pelo IAM, e não por ARN literal. Mantê-la verbatim como publicada pelo upstream torna trivial o diff quando o projeto atualizar o documento — é só substituir o arquivo.

**Inline e não managed policy.** A policy tem 4,8 KB sem espaços. O limite de managed policy é 6.144 caracteres (sem contar espaços); o de inline em role é 10.240. Passaria como managed, mas inline dá margem para o upstream crescer e evita que a policy seja anexada acidentalmente a outra role. É também o mesmo padrão do módulo `eks-karpenter`, onde inline era obrigatório.

### O nome

```hcl
role_name = coalesce(var.role_name, "${var.cluster_name}-aws-lb-controller")
```

Nome determinístico em vez de `name_prefix`, pela mesma razão do módulo `eks-karpenter`: o ARN da role vai numa annotation de `ServiceAccount`, e um nome com sufixo aleatório obrigaria a resolver output de Terraform em tempo de render do manifesto.

---

## `ssm.tf`

```hcl
ssm_parameters = var.create_ssm_parameters ? { "role-arn" = { ... } } : {}
```

Publica o ARN da role em `/aws-lb-controller/<cluster_name>/role-arn`, para que pipelines e geração de manifests leiam o valor sem acessar o tfstate.

É um map com uma entrada só, e não um `count`, por consistência com o módulo `eks-karpenter` — e porque adicionar um segundo valor no futuro não muda o endereço do primeiro no state.

---

## `outputs.tf` — `helm_values`

```hcl
output "helm_values" {
  value = {
    clusterName    = var.cluster_name
    vpcId          = var.vpc_id
    region         = local.region
    serviceAccount = { create = true, name = ..., annotations = { ... } }
  }
}
```

O consumidor faz `terraform output -json helm_values > values.yaml` e tem o arquivo pronto. O módulo continua fora do negócio de instalar charts, mas não empurra para o consumidor a tarefa de descobrir quais chaves do chart correspondem a quais outputs.

`service_account_name` e `namespace` também saem como output, ainda que sejam eco das entradas. O motivo é contratual: a trust policy foi construída sobre esses dois valores. Se a instalação do chart usar outros, o pod recebe `AccessDenied` sem pista do porquê — e a causa (trust policy apontando para um SA que não existe) é das mais difíceis de diagnosticar.

---

## O que o módulo não faz — e por quê

**Não instala o chart.** Plano Kubernetes. Exigir os providers `helm`/`kubernetes` obrigaria o consumidor a configurá-los apontando para um cluster que pode não existir no primeiro apply — e a se dividir em dois stages por causa disso. Só com o provider `aws`, o módulo cabe em qualquer root module.

**Não cria o `IngressClass`.** É um objeto do cluster, e o chart já o cria.

**Não tagueia as subnets.** O controller descobre onde criar o load balancer pelas tags `kubernetes.io/role/elb` (públicas) e `kubernetes.io/role/internal-elb` (privadas). Sem elas o `Ingress` fica pendente com `unable to discover subnets` — mas as subnets pertencem ao módulo `vpc`, e um módulo não deve alterar recursos de outro pelas costas. O `example/` mostra o lado da VPC configurado corretamente.

**Não desliga o webhook de mutação de Service.** O chart instala um webhook que intercepta todo `Service` do cluster e, antes dos pods do controller ficarem prontos, quebra a criação de Services de outros charts. É um problema real e comum — mas a decisão de desligá-lo (`enableServiceMutatorWebhook: false`) depende de você usar ou não `Service type=LoadBalancer`, e é um valor de chart. Fica documentado no README, não codificado aqui.
