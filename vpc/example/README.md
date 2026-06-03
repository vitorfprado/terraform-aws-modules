# Exemplo de consumo do módulo VPC

Estrutura pronta para copiar. O `source` aponta diretamente para o módulo publicado no GitHub (branch `main`).

## Estrutura

```
example/
├── main.tf                  # chamada do módulo vpc (source = github)
├── variables.tf
├── outputs.tf
├── versions.tf
└── terraform.tfvars.example
```

## Como usar

```bash
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan
terraform apply
```

## O que provisiona

- VPC `10.0.0.0/16`
- 3 subnets públicas e 3 privadas (uma por AZ, AZs selecionadas automaticamente)
- Internet Gateway
- 1 NAT Gateway (`single_nat_gateway = true`, econômico)

## Ajustes comuns

- **Alta disponibilidade de NAT:** defina `single_nat_gateway = false` no `main.tf` para um NAT por AZ.
- **Tags para EKS:** ao usar com o módulo EKS, adicione `public_subnet_tags`/`private_subnet_tags` (ver o [README do módulo VPC](../README.md#integração-com-o-módulo-eks)).
