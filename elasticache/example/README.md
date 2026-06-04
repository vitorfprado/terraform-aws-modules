# Exemplo de consumo do módulo ElastiCache

Estrutura pronta para copiar. Cria uma VPC e um Redis (single node) dentro dela. Os `source` apontam diretamente para os módulos publicados no GitHub (branch `main`).

## Estrutura

```
example/
├── main.tf                  # cria VPC + ElastiCache (módulos via GitHub)
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
- Redis 7.1 `cache.t4g.micro` single-node nas subnets privadas
- Security group liberando a porta `6379` apenas para o CIDR da VPC
- Criptografia em repouso habilitada

## Observações

- O exemplo usa `num_cache_clusters = 1` (single-node, sem failover) para reduzir custo. Para alta disponibilidade, use `num_cache_clusters = 2` + `automatic_failover_enabled = true` + `multi_az_enabled = true`.
- `transit_encryption_enabled` fica em `false` no exemplo para simplificar o acesso. Habilite em produção (exige clientes TLS).
- Para subir mais de um cache, adicione outro bloco `module "elasticache_xxx"` com um `name` diferente.
- Para liberar acesso a partir de um cluster EKS, use `allowed_security_group_ids = [module.eks.cluster_security_group_id]`.
