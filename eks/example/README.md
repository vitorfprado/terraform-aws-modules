# Exemplo de consumo do módulo EKS

Esta pasta é um ponto de partida pronto para uso. Copie os arquivos para o seu repositório de infraestrutura, ajuste os valores e aplique.

Os módulos são referenciados **diretamente do GitHub** (branch `main`), então não é necessário ter este repositório clonado para consumi-los:

```hcl
module "vpc" {
  source = "github.com/vitorfprado/terraform-aws-modules//vpc?ref=main"
  # ...
}

module "eks" {
  source = "github.com/vitorfprado/terraform-aws-modules//eks?ref=main"
  # ...
}
```

## Estrutura

```
example/
├── main.tf                  # cria a VPC e o cluster (módulos vpc + eks + addons)
├── variables.tf             # variáveis de entrada do exemplo
├── outputs.tf               # outputs úteis (vpc, endpoint, OIDC, kubeconfig)
├── versions.tf              # versões e providers (aws, kubernetes, helm)
└── terraform.tfvars.example # valores de exemplo
```

## Pré-requisitos

- Terraform >= 1.5
- Credenciais AWS configuradas (`aws configure` ou variáveis de ambiente)
- `aws` CLI e `kubectl` instalados localmente

> A VPC é criada pelo próprio exemplo (módulo `vpc`). Não é necessário informar uma rede existente.

## Como usar

1. Copie o arquivo de variáveis e ajuste o `admin_role_arn` (e opcionalmente `region`, `cluster_name`):

   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

2. Inicialize e aplique:

   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

3. Gere o kubeconfig local (o comando é exposto como output):

   ```bash
   aws eks update-kubeconfig --region us-east-1 --name demo
   kubectl get nodes
   ```

## O que este exemplo provisiona

- **VPC** `10.0.0.0/16` com 3 subnets públicas e 3 privadas (uma por AZ), Internet Gateway e 1 NAT Gateway, já com as tags de subnet exigidas pelo EKS e pelo Karpenter
- Cluster EKS com criptografia de secrets via KMS e logs do control plane no CloudWatch
- OIDC provider habilitado para IRSA
- Dois managed node groups: um `ON_DEMAND` (`general`) e um `SPOT` com taint (`spot`)
- Add-ons gerenciados: `coredns`, `kube-proxy`, `vpc-cni`, `eks-pod-identity-agent` e o `aws-ebs-csi-driver` (com IRSA, para volumes EBS dinâmicos)
- Uma access entry concedendo acesso de administrador ao `admin_role_arn`

Um único `terraform apply` resolve a ordem: VPC → EKS → add-ons.

## Add-ons opcionais via Helm

Este exemplo também demonstra a instalação de componentes via Helm, usando o submódulo [`../addons`](../addons). Os providers `helm` e `kubernetes` já estão configurados em [`versions.tf`](./versions.tf) com autenticação via `aws eks get-token`.

Todos os add-ons vêm **desabilitados**. Para instalar, defina a flag correspondente como `true` em `terraform.tfvars`:

| Variável | Componente |
|----------|------------|
| `enable_metrics_server` | Metrics Server |
| `enable_aws_load_balancer_controller` | AWS Load Balancer Controller (cria IRSA) |
| `enable_cert_manager` | cert-manager |
| `enable_external_secrets` | External Secrets Operator |
| `enable_kube_prometheus_stack` | Prometheus + Grafana + Alertmanager |
| `enable_argocd` | Argo CD |
| `enable_karpenter` | Karpenter (autoscaling de nós; cria IRSA, SQS e EventBridge) |

Exemplo — habilitar apenas Metrics Server e AWS Load Balancer Controller:

```hcl
enable_metrics_server               = true
enable_aws_load_balancer_controller = true
```

Detalhes de cada componente, versões de chart e pontos de atenção (IRSA, CRDs, tags de subnet) estão documentados em [`../addons/README.md`](../addons/README.md).

> **Importante:** os add-ons exigem o `aws` CLI instalado localmente (usado pelo `exec` dos providers) e que o cluster já esteja acessível. Em um apply do zero, o Terraform cria o cluster antes dos releases Helm.

## Ajustes comuns

- **Endpoint privado:** defina `endpoint_public_access = false` para restringir o acesso à API à VPC.
- **Restringir o acesso público:** troque `public_access_cidrs` pelos CIDRs da sua rede corporativa/VPN.
- **Node groups:** adicione ou remova entradas no mapa `node_groups`. Cada chave vira o sufixo do nome do node group.
- **Add-ons:** fixe versões informando `version = "v1.x.x-eksbuild.y"` em cada add-on.
