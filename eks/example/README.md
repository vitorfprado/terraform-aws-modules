# Exemplo de consumo do módulo EKS

Esta pasta é um ponto de partida pronto para uso. Copie os arquivos para o seu repositório de infraestrutura, ajuste os valores e aplique.

## Estrutura

```
example/
├── main.tf                  # chamada do módulo eks
├── variables.tf             # variáveis de entrada do exemplo
├── outputs.tf               # outputs úteis (endpoint, OIDC, kubeconfig)
├── versions.tf              # versões e provider aws
└── terraform.tfvars.example # valores de exemplo
```

## Pré-requisitos

- Terraform >= 1.5
- Credenciais AWS configuradas (`aws configure` ou variáveis de ambiente)
- Uma VPC existente com pelo menos duas subnets em zonas de disponibilidade distintas (recomenda-se subnets privadas com NAT)

## Como usar

1. Copie o arquivo de variáveis e preencha com os seus valores:

   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

2. Ajuste `terraform.tfvars` com o `vpc_id`, as `subnet_ids` e o `admin_role_arn` do seu ambiente.

3. Inicialize e aplique:

   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

4. Gere o kubeconfig local (o comando é exposto como output):

   ```bash
   aws eks update-kubeconfig --region us-east-1 --name demo
   kubectl get nodes
   ```

## O que este exemplo provisiona

- Cluster EKS com criptografia de secrets via KMS e logs do control plane no CloudWatch
- OIDC provider habilitado para IRSA
- Dois managed node groups: um `ON_DEMAND` (`general`) e um `SPOT` com taint (`spot`)
- Add-ons gerenciados: `coredns`, `kube-proxy`, `vpc-cni` e `eks-pod-identity-agent`
- Uma access entry concedendo acesso de administrador ao `admin_role_arn`

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
