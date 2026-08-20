# Exemplo — eks-karpenter

Sobe uma VPC (com as tags de discovery), um cluster EKS com um node group de baseline e toda a infraestrutura AWS do Karpenter: role dos nós, IRSA do controller, fila de interrupção e regras do EventBridge.

O módulo **não instala o chart**. Depois do apply, os outputs trazem tudo que a instalação precisa.

## Uso

```bash
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan
terraform apply
```

## Instalando o chart depois

Com `helm` diretamente:

```bash
CLUSTER=$(terraform output -raw -json helm_values | jq -r .settings.clusterName)
ROLE_ARN=$(terraform output -raw controller_role_arn)
QUEUE=$(terraform output -raw interruption_queue_name)

helm upgrade --install karpenter oci://public.ecr.aws/karpenter/karpenter \
  --version "1.3.3" \
  --namespace kube-system \
  --set "settings.clusterName=${CLUSTER}" \
  --set "settings.interruptionQueue=${QUEUE}" \
  --set "serviceAccount.name=karpenter" \
  --set "serviceAccount.annotations.eks\.amazonaws\.com/role-arn=${ROLE_ARN}"
```

Ou gerando o `values.yaml` a partir do output:

```bash
terraform output -json helm_values | jq . > karpenter-values.yaml
helm upgrade --install karpenter oci://public.ecr.aws/karpenter/karpenter \
  --version "1.3.3" --namespace kube-system -f karpenter-values.yaml
```

> A versão do chart é escolha sua — o módulo não opina. Karpenter `>= 1.2` é necessário para Kubernetes 1.32; versões anteriores derrubam o controller com `not compatible with K8s version 1.32`.

## EC2NodeClass e NodePool

O chart sobe o controller, mas ele não provisiona nada sem um `NodePool` e um `EC2NodeClass`. O `spec.role` do `EC2NodeClass` é o output `node_role_name`:

```yaml
apiVersion: karpenter.k8s.aws/v1
kind: EC2NodeClass
metadata:
  name: default
spec:
  role: <node_role_name>
  amiSelectorTerms:
    - alias: al2023@latest
  subnetSelectorTerms:
    - tags:
        karpenter.sh/discovery: <cluster_name>
  securityGroupSelectorTerms:
    - tags:
        karpenter.sh/discovery: <cluster_name>
```

As tags `karpenter.sh/discovery` nas subnets vêm do módulo `vpc` (ver `main.tf`). O security group do cluster precisa da mesma tag — o módulo `eks` a aplica quando você a inclui em `tags`.

## Limpeza

```bash
terraform destroy
```

> Remova os `NodePool` antes do destroy. Nós provisionados pelo Karpenter não estão no state do Terraform e ficariam órfãos, impedindo a remoção da VPC.
