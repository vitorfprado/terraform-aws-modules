# Exemplo — iam-irsa

Sobe uma VPC, um cluster EKS (com OIDC/IRSA habilitado) e duas roles IRSA:

- `irsa_analytics` — policy **inline** (SQS + DynamoDB) e ARN publicado no **SSM Parameter Store**.
- `irsa_readonly` — apenas uma **managed policy** (`AmazonS3ReadOnlyAccess`).

## Uso

```bash
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan
terraform apply
```

Após o apply, anote o `analytics_role_arn` na annotation do ServiceAccount:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: analytics-service
  namespace: togglemaster
  annotations:
    eks.amazonaws.com/role-arn: <analytics_role_arn>
```

> O exemplo cria um cluster EKS completo (NAT + nós), o que leva ~15 min e gera
> custo enquanto existir. Rode `terraform destroy` ao terminar.
