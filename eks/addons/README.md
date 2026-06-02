# Submódulo – EKS Add-ons (Helm)

Instala componentes opcionais em um cluster EKS já existente, via Helm. Todos os componentes vêm **desabilitados por padrão** e são habilitados individualmente por flags booleanas.

Este submódulo **não** cria o cluster nem configura os providers. Ele recebe os dados de um cluster (saídas do módulo [`../`](../)) e assume que os providers `helm` e `kubernetes` foram configurados no root, apontando para o cluster (ver [`../example`](../example)).

## Componentes suportados

| Flag | Componente | Namespace | IAM/IRSA |
|------|------------|-----------|:--------:|
| `enable_metrics_server` | Metrics Server | `kube-system` | não |
| `enable_aws_load_balancer_controller` | AWS Load Balancer Controller | `kube-system` | **sim** |
| `enable_cert_manager` | cert-manager | `cert-manager` | não |
| `enable_external_secrets` | External Secrets Operator | `external-secrets` | não* |
| `enable_kube_prometheus_stack` | kube-prometheus-stack | `monitoring` | não |
| `enable_argocd` | Argo CD | `argocd` | não |

\* O External Secrets Operator é instalado sem IRSA. Cada `SecretStore`/`ClusterSecretStore` define a própria autenticação — para acessar AWS Secrets Manager/SSM, crie uma role IRSA dedicada e referencie-a no `serviceAccountRef`. Ver [Pontos de atenção](#pontos-de-atenção).

## Uso

```hcl
module "eks" {
  source = "../"
  # ...
}

module "addons" {
  source = "../addons"

  cluster_name      = module.eks.cluster_name
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url
  vpc_id            = var.vpc_id
  region            = var.region

  enable_metrics_server               = true
  enable_aws_load_balancer_controller = true
  enable_cert_manager                 = false
  enable_external_secrets             = false
  enable_kube_prometheus_stack        = false
  enable_argocd                       = false

  depends_on = [module.eks]
}
```

> O `depends_on = [module.eks]` garante que o cluster exista antes de qualquer release Helm.

## Variáveis principais

### Conexão com o cluster (obrigatórias)

| Nome | Descrição |
|------|-----------|
| `cluster_name` | Nome do cluster EKS. |
| `oidc_provider_arn` | ARN do OIDC provider (output `oidc_provider_arn` do módulo eks). |
| `oidc_provider_url` | URL do issuer OIDC (output `oidc_provider_url` do módulo eks). |
| `vpc_id` | ID da VPC. Usado pelo AWS Load Balancer Controller. |
| `region` | Região AWS (opcional; resolvida automaticamente quando nula). |

### Por componente

Cada componente expõe, além do `enable_*`:

- `*_chart_version` – versão do chart Helm (com defaults fixados).
- `*_namespace` – namespace dedicado (para cert-manager, ESO, prometheus e argocd).
- `*_helm_values` – `list(string)` de documentos YAML para sobrescrever valores do chart.
- `cert_manager_install_crds` / `external_secrets_install_crds` – controlam a instalação dos CRDs (default `true`).

Exemplo de override de valores:

```hcl
kube_prometheus_stack_helm_values = [
  yamlencode({
    grafana = {
      adminPassword = "trocar"
    }
  })
]
```

## Pontos de atenção

- **AWS Load Balancer Controller:** requer IRSA. O submódulo cria a IAM role, a policy (a partir de [`policies/aws_lbc_iam_policy.json`](./policies/aws_lbc_iam_policy.json), a policy oficial v2.x) e o service account anotado. Exige que `enable_irsa = true` no módulo eks (padrão) e que as subnets estejam taggeadas com `kubernetes.io/role/elb` (públicas) e `kubernetes.io/role/internal-elb` (privadas) para o auto-discovery funcionar.
- **CRDs (cert-manager / ESO):** instalados junto com o chart por padrão. Ao desinstalar, os CRDs podem permanecer no cluster — remova-os manualmente se necessário.
- **External Secrets Operator:** para ler segredos da AWS, crie uma role IRSA com permissões mínimas (ex.: `secretsmanager:GetSecretValue` no ARN específico) e associe-a ao service account do `SecretStore`.
- **kube-prometheus-stack:** instala um volume considerável de CRDs e recursos. Avalie a capacidade dos node groups antes de habilitar.
- **Argo CD:** após a instalação, recupere a senha inicial do admin com `kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d`.
- **Partition:** a policy do LBC usa ARNs `arn:aws:...`. Para GovCloud/China, ajuste o arquivo JSON.
