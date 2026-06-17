# Exemplo de consumo do módulo EC2

Estrutura pronta para copiar. Cria uma VPC e uma instância EC2 em subnet privada, acessível via SSM Session Manager (sem chave SSH nem IP público). Os `source` apontam diretamente para os módulos publicados no GitHub (branch `main`).

## Estrutura

```
example/
├── main.tf                  # cria VPC + EC2 (módulos via GitHub)
├── variables.tf
├── outputs.tf
├── versions.tf
└── terraform.tfvars.example
```

## Pré-requisitos

- Terraform >= 1.5
- Credenciais AWS configuradas
- Plugin do Session Manager para usar o acesso SSM (`aws ssm start-session`)

## Como usar

```bash
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan
terraform apply
```

Depois, conecte via SSM (o comando é exposto como output):

```bash
aws ssm start-session --target <instance_id> --region us-east-1
```

## O que provisiona

- VPC `10.0.0.0/16` com subnets públicas e privadas e 1 NAT Gateway
- Instância `t3.micro` com Amazon Linux 2023 (lookup automático) em subnet privada
- IAM instance profile com `AmazonSSMManagedInstanceCore`
- Volume raiz criptografado e IMDSv2 forçado
- Security group sem regras de entrada (o SSM funciona pela saída via NAT)

## Observações

- A instância **não tem IP público nem porta aberta** — o acesso é só via SSM, que é o padrão recomendado.
- O acesso SSM depende da saída para a internet (o NAT da VPC) ou de VPC endpoints do SSM.
- Para subir mais de uma instância, adicione outro bloco `module "ec2_xxx"` com um `name` diferente.
- Para um servidor público (web), use uma subnet pública, `associate_public_ip_address = true`, `create_eip = true` e `ingress_rules` — ver o [README do módulo](../README.md).
