# Módulo Terraform – VPC

Provisiona uma VPC na AWS com subnets públicas e privadas distribuídas em múltiplas zonas de disponibilidade, Internet Gateway, NAT Gateways e route tables. Projetado para ser reutilizado por outros módulos (EKS, RDS, ElastiCache, etc.) que apenas consomem `vpc_id` e os IDs das subnets.

## Recursos criados

- `aws_vpc`
- `aws_subnet` – públicas e privadas, uma por AZ
- `aws_internet_gateway`
- `aws_nat_gateway` + `aws_eip` – único (econômico) ou um por AZ (HA)
- `aws_route_table` / `aws_route` / `aws_route_table_association`

## Uso

```hcl
module "vpc" {
  source = "github.com/vitorfprado/terraform-aws-modules//vpc?ref=main"

  name       = "producao"
  cidr_block = "10.0.0.0/16"

  public_subnet_cidrs  = ["10.0.0.0/20", "10.0.16.0/20", "10.0.32.0/20"]
  private_subnet_cidrs = ["10.0.48.0/20", "10.0.64.0/20", "10.0.80.0/20"]

  enable_nat_gateway = true
  single_nat_gateway = true

  tags = {
    Environment = "producao"
  }
}
```

As AZs são selecionadas automaticamente conforme a quantidade de subnets. Para fixá-las, informe `azs`. Um exemplo copiável está em [`example/`](./example).

## Requisitos

| Nome      | Versão   |
|-----------|----------|
| terraform | >= 1.5   |
| aws       | >= 5.40  |

## Variáveis de entrada

| Nome | Descrição | Tipo | Padrão | Obrigatória |
|------|-----------|------|--------|:-----------:|
| `name` | Nome base e prefixo dos recursos. | `string` | — | sim |
| `cidr_block` | Bloco CIDR primário da VPC. | `string` | `"10.0.0.0/16"` | não |
| `azs` | AZs a utilizar. Vazio = automático. | `list(string)` | `[]` | não |
| `public_subnet_cidrs` | CIDRs das subnets públicas (uma por AZ). | `list(string)` | `[]` | não |
| `private_subnet_cidrs` | CIDRs das subnets privadas (uma por AZ). | `list(string)` | `[]` | não |
| `enable_nat_gateway` | Cria NAT Gateways para as subnets privadas. | `bool` | `true` | não |
| `single_nat_gateway` | Um único NAT (econômico) vs. um por AZ (HA). | `bool` | `false` | não |
| `map_public_ip_on_launch` | IP público automático nas subnets públicas. | `bool` | `true` | não |
| `enable_dns_support` | Habilita resolução DNS na VPC. | `bool` | `true` | não |
| `enable_dns_hostnames` | Habilita hostnames DNS (necessário p/ EKS). | `bool` | `true` | não |
| `public_subnet_tags` | Tags extras nas subnets públicas. | `map(string)` | `{}` | não |
| `private_subnet_tags` | Tags extras nas subnets privadas. | `map(string)` | `{}` | não |
| `tags` | Tags aplicadas a todos os recursos. | `map(string)` | `{}` | não |

> Para `single_nat_gateway = false`, forneça o mesmo número de subnets públicas e privadas (uma por AZ), pois cada subnet privada roteia para o NAT da sua AZ.

## Outputs

| Nome | Descrição |
|------|-----------|
| `vpc_id` | ID da VPC. |
| `vpc_arn` | ARN da VPC. |
| `vpc_cidr_block` | Bloco CIDR da VPC. |
| `public_subnet_ids` | IDs das subnets públicas. |
| `private_subnet_ids` | IDs das subnets privadas. |
| `public_subnet_cidrs` | CIDRs das subnets públicas. |
| `private_subnet_cidrs` | CIDRs das subnets privadas. |
| `public_route_table_id` | ID da route table pública. |
| `private_route_table_ids` | IDs das route tables privadas. |
| `internet_gateway_id` | ID do Internet Gateway. |
| `nat_gateway_ids` | IDs dos NAT Gateways. |
| `nat_public_ips` | IPs públicos dos NAT Gateways. |
| `azs` | AZs utilizadas. |
