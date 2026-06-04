# Exemplo de consumo do módulo RDS

Estrutura pronta para copiar. Cria uma VPC e uma instância PostgreSQL dentro dela. Os `source` apontam diretamente para os módulos publicados no GitHub (branch `main`).

## Estrutura

```
example/
├── main.tf                  # cria VPC + RDS (módulos via GitHub)
├── variables.tf
├── outputs.tf
├── versions.tf
└── terraform.tfvars.example
```

## Pré-requisitos

- Terraform >= 1.5
- Credenciais AWS configuradas

## Como usar

```bash
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan
terraform apply
```

## O que provisiona

- VPC `10.0.0.0/16` com subnets públicas e privadas e 1 NAT Gateway
- Instância **PostgreSQL 16** `db.t3.micro` nas subnets privadas
- Security group liberando a porta `5432` apenas para o CIDR da VPC
- KMS key dedicada para criptografia do armazenamento
- Senha do usuário master gerenciada pelo Secrets Manager (output `master_user_secret_arn`)

## Recuperando a senha do banco

```bash
aws secretsmanager get-secret-value \
  --secret-id "$(terraform output -raw master_user_secret_arn)" \
  --query SecretString --output text
```

## Observações

- O exemplo usa `deletion_protection = false` e `skip_final_snapshot = true` para facilitar o `terraform destroy`. **Em produção, mantenha os defaults do módulo** (`true` e `false`).
- Para subir mais de um banco, basta adicionar outro bloco `module "rds_xxx"` com um `name` diferente.
- Para liberar acesso a partir de um cluster EKS, use `allowed_security_group_ids = [module.eks.cluster_security_group_id]` em vez de `allowed_cidr_blocks`.
