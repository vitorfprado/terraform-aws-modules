# Explicação detalhada — módulo VPC

Este documento percorre cada arquivo do módulo explicando **o que o código faz e por quê foi escrito assim**.

---

## `variables.tf`

### Variáveis obrigatórias e de rede

`name` é a única variável sem default. Ela vira prefixo em todos os recursos (`demo-public-us-east-1a`, `demo-nat-1`, etc.), então é essencial para identificar o que foi criado por qual instância do módulo.

`cidr_block` define o espaço de endereçamento inteiro da VPC — o "envelope" do qual todos os CIDRs de subnet são subconjuntos. O default `10.0.0.0/16` dá 65 536 endereços disponíveis para distribuir.

`public_subnet_cidrs` e `private_subnet_cidrs` são listas de CIDRs menores, um por AZ. Listas vazias (o default) fazem o módulo não criar aquele tipo de subnet. Isso permite usar o módulo apenas com subnets privadas, por exemplo.

### Zonas de disponibilidade

`azs` permite fixar manualmente quais zonas usar. Quando fica vazio (default), o módulo descobre as AZs automaticamente a partir da quantidade de subnets passadas — você controla a quantidade de AZs pelo tamanho das listas de CIDR, não por um parâmetro separado.

### NAT Gateway

Dois campos controlam o comportamento do NAT:

- `enable_nat_gateway` — se `false`, subnets privadas ficam sem saída para a internet (sem pull de imagens, sem atualizações de SO).
- `single_nat_gateway` — tradeoff direto entre custo e resiliência. Um NAT Gateway cobra por hora (~$32/mês na us-east-1). Com `false` (padrão), cada AZ ganha seu próprio NAT: se uma AZ cair, as outras continuam operando. Com `true`, todas as subnets privadas roteiam pelo mesmo NAT — mais barato mas ponto único de falha.

### Tags de subnet

`public_subnet_tags` e `private_subnet_tags` recebem tags extras aplicadas apenas nas subnets de cada tipo. O módulo não sabe nem precisa saber quem vai usar a VPC — quem consome passa as tags que o seu workload exige (EKS, Karpenter, RDS, etc.) por aqui.

---

## `main.tf`

### `data "aws_availability_zones"` + `locals`

```hcl
data "aws_availability_zones" "available" {
  state = "available"
}
```

Consulta a AWS no momento do `plan` para listar as AZs disponíveis na região atual. O resultado só é usado quando `var.azs` está vazio.

```hcl
locals {
  max_subnet_count  = max(length(var.public_subnet_cidrs), length(var.private_subnet_cidrs))
  azs               = length(var.azs) > 0 ? var.azs : slice(..., 0, local.max_subnet_count)
  nat_gateway_count = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.public_subnet_cidrs)) : 0
}
```

**`max_subnet_count`** — determina quantas AZs são necessárias. Usa `max` porque você pode ter mais subnets públicas do que privadas, ou vice-versa.

**`azs`** — se `var.azs` foi informado, usa ele. Caso contrário, pega as primeiras N AZs disponíveis via `slice`. A elegância aqui é que o número de AZs é implícito: você define quantas quer pelo tamanho das listas de CIDR.

**`nat_gateway_count`** — resolve a lógica de três caminhos em uma linha:
- NAT desabilitado → `0`
- NAT único → `1`
- NAT por AZ → igual ao número de subnets públicas

### VPC e Internet Gateway

```hcl
resource "aws_vpc" "main" { ... }

resource "aws_internet_gateway" "igw" {
  count = length(var.public_subnet_cidrs) > 0 ? 1 : 0
  ...
}
```

O IGW só existe se há subnets públicas — sem elas não há razão para um gateway de internet. Usar `count` aqui (em vez de deixar sempre criado) evita um recurso órfão quando o módulo é usado só com subnets privadas.

### Subnets com `count`

```hcl
resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)

  cidr_block        = var.public_subnet_cidrs[count.index]
  availability_zone = element(local.azs, count.index)
  ...
}
```

O Terraform instancia um recurso por item da lista. `count.index` vai de 0, 1, 2... mapeando cada CIDR à sua AZ correspondente:

- índice 0 → `"10.0.0.0/20"` em `us-east-1a`
- índice 1 → `"10.0.16.0/20"` em `us-east-1b`
- índice 2 → `"10.0.32.0/20"` em `us-east-1c`

`element()` é usado em vez de acesso direto `local.azs[count.index]` como proteção: se por algum motivo houvesse mais CIDRs do que AZs disponíveis, `element` faz wrap circular ao invés de explodir com index out of bounds.

As tags seguem o mesmo índice para nomear corretamente: `demo-public-us-east-1a`.

### NAT Gateway e Elastic IPs

```hcl
resource "aws_eip" "nat" {
  count  = local.nat_gateway_count
  domain = "vpc"
}

resource "aws_nat_gateway" "ngw" {
  count         = local.nat_gateway_count
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
  depends_on    = [aws_internet_gateway.igw]
}
```

Cada NAT precisa de um Elastic IP — um IP público fixo pelo qual todo o tráfego de saída das subnets privadas aparece na internet. O `depends_on` no IGW é necessário porque o NAT precisa que o gateway exista antes de poder rotear tráfego, e o Terraform não consegue inferir essa dependência automaticamente.

### Route tables — pública vs. privada

**Pública — uma para todas:**

```hcl
resource "aws_route_table" "public" {
  count = length(var.public_subnet_cidrs) > 0 ? 1 : 0
  ...
}
resource "aws_route" "public_internet" {
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw[0].id
}
resource "aws_route_table_association" "public" {
  count          = length(var.public_subnet_cidrs)
  route_table_id = aws_route_table.public[0].id  # todas apontam para a mesma
}
```

Uma única route table com rota `0.0.0.0/0 → IGW` associada a todas as subnets públicas. Faz sentido porque todas têm o mesmo comportamento de roteamento: qualquer destino desconhecido vai para a internet.

**Privada — uma por AZ:**

```hcl
resource "aws_route_table" "private" {
  count = length(var.private_subnet_cidrs)  # uma por subnet
  ...
}
resource "aws_route" "private_nat" {
  route_table_id = aws_route_table.private[count.index].id
  nat_gateway_id = aws_nat_gateway.ngw[var.single_nat_gateway ? 0 : count.index].id
}
```

Esta é a decisão mais importante do módulo. Subnets privadas precisam de route tables separadas por causa do modo HA (`single_nat_gateway = false`):

- Com **NAT único**: todas as route tables apontam para `ngw[0]` (o índice `? 0 : ...` sempre retorna 0).
- Com **NAT por AZ**: a subnet da AZ 1 roteia pelo NAT da AZ 1, a da AZ 2 pelo NAT da AZ 2. Se a AZ 1 cair, as outras AZs continuam com seus próprios NATs sem interrupção.

Se usássemos uma route table compartilhada para as privadas (como nas públicas), o modo HA seria impossível de implementar — todas as subnets apontariam para o mesmo NAT independente do `single_nat_gateway`.

---

## Fluxo completo de um pacote saindo de uma subnet privada

```
Pod / instância (10.0.48.5)
  │
  ├─ Route table privada da AZ: 0.0.0.0/0 → NAT Gateway
  │
  ├─ NAT Gateway (na subnet pública, com EIP 54.x.x.x)
  │   ─ faz SNAT: troca o IP de origem 10.0.48.5 pelo EIP
  │
  ├─ Route table pública: 0.0.0.0/0 → Internet Gateway
  │
  └─ Internet Gateway → Internet
```

O retorno segue o caminho inverso: o NAT mantém uma tabela de tradução para saber qual IP privado interno corresponde a cada conexão de saída.
