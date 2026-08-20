# Exemplo — eks-aws-lb-controller

Sobe uma VPC (com as tags de discovery de subnet), um cluster EKS e a IAM role (IRSA) do AWS Load Balancer Controller.

O módulo **não instala o chart** — depois do apply, o output traz o que a instalação precisa.

## Uso

```bash
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan
terraform apply
```

## Instalando o chart depois

```bash
terraform output -json helm_values | jq . > lbc-values.yaml

helm repo add eks https://aws.github.io/eks-charts
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  --version "1.8.1" --namespace kube-system -f lbc-values.yaml
```

> A versão do chart é escolha sua — o módulo não opina.

### Webhook de mutação de Service

O chart instala, por padrão, um webhook que intercepta **todo** `Service` do cluster. Enquanto os pods do controller não estiverem prontos, isso quebra a criação de Services de outros charts com `no endpoints available for service aws-load-balancer-webhook-service`.

Se você só usa `Ingress` (ALB) e nunca `Service type=LoadBalancer`, o webhook é dispensável:

```yaml
enableServiceMutatorWebhook: false
```

## Testando

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: demo
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
spec:
  ingressClassName: alb
  rules:
    - http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: demo
                port:
                  number: 80
```

## Limpeza

```bash
terraform destroy
```

> Remova os `Ingress` antes do destroy. Os ALBs criados pelo controller não estão no state do Terraform e ficariam órfãos, impedindo a remoção da VPC.
