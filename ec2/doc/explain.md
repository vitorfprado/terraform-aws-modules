# Explicação detalhada — módulo EC2

Este documento percorre cada arquivo do módulo explicando **o que o código faz e por quê foi escrito assim**.

O EC2 é um recurso **dentro da VPC** (como RDS e ElastiCache): recebe `vpc_id` e `subnet_id` de fora. Cada chamada do módulo cria **uma** instância — para várias, chama-se o módulo várias vezes.

---

## `variables.tf`

### AMI: explícita ou lookup automático

```hcl
variable "ami_id"           { default = null }
variable "ami_architecture" { default = "x86_64" }
```

Hardcodar um ID de AMI é frágil — IDs mudam por região e ficam desatualizados. Por isso, quando `ami_id` é nulo, o módulo busca a Amazon Linux 2023 mais recente (ver `main.tf`). `ami_architecture` cobre o caso de instâncias Graviton (ARM), que exigem uma imagem `arm64`.

### Segurança por padrão

Dois defaults são escolhas de segurança deliberadas:

- `metadata_http_tokens = "required"` — força o IMDSv2. O IMDSv1 é vulnerável a SSRF (um atacante que consegue fazer a aplicação emitir um GET para `169.254.169.254` rouba as credenciais da instância). O IMDSv2 exige um token via PUT, bloqueando esse vetor.
- `root_volume_encrypted = true` — criptografia transparente do disco.

---

## `main.tf` — lookup da AMI, locals e instância

### Lookup da AMI

```hcl
data "aws_ami" "al2023" {
  count       = var.ami_id == null ? 1 : 0
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-${var.ami_architecture}"]
  }
  filter {
    name   = "state"
    values = ["available"]
  }
}
```

O `count` faz a consulta só acontecer quando o usuário não informou uma AMI. `most_recent = true` com `owners = ["amazon"]` garante a imagem oficial mais nova. O filtro por `name` usa o padrão de nomenclatura da AL2023 com a arquitetura interpolada.

### locals

```hcl
locals {
  ami_id = var.ami_id != null ? var.ami_id : data.aws_ami.al2023[0].id

  any_volume_encrypted    = var.root_volume_encrypted || anytrue([for v in var.ebs_volumes : v.encrypted])
  create_kms_key_resource = local.any_volume_encrypted && var.create_kms_key && var.kms_key_arn == null
  kms_key_arn             = var.kms_key_arn != null ? var.kms_key_arn : (local.create_kms_key_resource ? aws_kms_key.ec2[0].arn : null)

  security_group_ids   = var.create_security_group ? concat([aws_security_group.ec2[0].id], var.vpc_security_group_ids) : var.vpc_security_group_ids
  iam_instance_profile = var.create_iam_instance_profile ? aws_iam_instance_profile.ec2[0].name : var.iam_instance_profile
}
```

**`any_volume_encrypted`** usa `anytrue` com uma list comprehension para detectar se *qualquer* volume (raiz ou adicional) precisa de criptografia. Só faz sentido criar uma KMS key se houver pelo menos um volume criptografado.

**`security_group_ids`** e **`iam_instance_profile`** seguem o mesmo padrão dos outros módulos: resolvem entre "criado pelo módulo" e "informado pelo usuário".

### A instância

```hcl
resource "aws_instance" "main" {
  ami                  = local.ami_id
  ...
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = var.metadata_http_tokens
    http_put_response_hop_limit = var.metadata_http_put_response_hop_limit
  }

  root_block_device {
    volume_size = var.root_volume_size
    volume_type = var.root_volume_type
    encrypted   = var.root_volume_encrypted
    kms_key_id  = var.root_volume_encrypted ? local.kms_key_arn : null
  }
}
```

O bloco `metadata_options` é o que aplica o IMDSv2. O `http_put_response_hop_limit` merece atenção: o default `1` impede que um container na instância acesse o metadata (o salto extra de rede do container é bloqueado) — bom para segurança. Quando a carga roda containers que precisam de credenciais via metadata, sobe-se para `2`.

O `kms_key_id` no volume raiz só é enviado quando há criptografia; com `null`, a AWS usa a chave padrão `aws/ebs`.

### Volumes adicionais e a dependência de AZ

```hcl
resource "aws_ebs_volume" "additional" {
  for_each          = { for v in var.ebs_volumes : v.device_name => v }
  availability_zone = aws_instance.main.availability_zone
  ...
}

resource "aws_volume_attachment" "additional" {
  for_each    = { for v in var.ebs_volumes : v.device_name => v }
  device_name = each.key
  volume_id   = aws_ebs_volume.additional[each.key].id
  instance_id = aws_instance.main.id
}
```

Os volumes EBS são recursos separados (não `ebs_block_device` inline) porque assim podem ser redimensionados ou substituídos sem forçar a recriação da instância. O `for_each` é indexado por `device_name`, que é único por instância.

**Detalhe crítico:** um volume EBS só pode ser anexado a uma instância na **mesma AZ**. Por isso a `availability_zone` do volume vem de `aws_instance.main.availability_zone` — em vez de tentar adivinhar a AZ pela subnet, o módulo simplesmente usa a AZ real onde a instância caiu. Isso cria a dependência correta: a instância é criada primeiro, depois os volumes na AZ dela.

---

## `security_group.tf`

Diferente de RDS/ElastiCache (que abrem uma única porta), o EC2 precisa de regras de entrada variadas. Por isso o módulo recebe uma lista `ingress_rules` e a transforma em recursos:

```hcl
resource "aws_vpc_security_group_ingress_rule" "ec2" {
  for_each = var.create_security_group ? { for idx, rule in var.ingress_rules : tostring(idx) => rule } : {}
  ...
  cidr_ipv4                    = each.value.cidr_ipv4
  referenced_security_group_id = each.value.referenced_security_group_id
}
```

O `for_each` converte a lista em mapa com chaves de índice (`"0"`, `"1"`, ...). Cada regra define `cidr_ipv4` **ou** `referenced_security_group_id`; o não utilizado fica `null` e é simplesmente ignorado pelo recurso. Continua usando regras como recursos separados (não inline) pelo mesmo motivo dos outros módulos: evitar *perpetual diffs*.

---

## `iam.tf` — instance profile opcional

```hcl
resource "aws_iam_role" "ec2"             { count = var.create_iam_instance_profile ? 1 : 0 ... }
resource "aws_iam_role_policy_attachment" "ec2" { for_each = var.create_iam_instance_profile ? var.iam_role_policy_arns : {} ... }
resource "aws_iam_instance_profile" "ec2" { count = var.create_iam_instance_profile ? 1 : 0 ... }
```

Uma instância EC2 não usa uma role diretamente — ela usa um **instance profile**, que é um contêiner para a role. Por isso o módulo cria os dois: a role (com trust em `ec2.amazonaws.com`) e o instance profile que a referencia.

O `iam_role_policy_arns` é um **mapa** (não lista) para que o `for_each` tenha chaves estáveis: remover uma política do meio não recria as outras. O uso mais comum é anexar `AmazonSSMManagedInstanceCore`, que habilita o acesso via Session Manager sem SSH.

---

## `kms.tf`

Mesma estrutura dos demais módulos: key dedicada opcional, criada só quando há volume criptografado **e** o usuário pede uma key própria. Caso contrário, os volumes usam a chave gerenciada `aws/ebs`.

---

## Acesso à instância: SSM vs SSH

O módulo favorece o **SSM Session Manager**, refletido no exemplo: instância em subnet privada, sem IP público, sem porta 22 aberta, com instance profile contendo `AmazonSSMManagedInstanceCore`. O acesso é feito por:

```bash
aws ssm start-session --target <instance_id>
```

Isso elimina a superfície de ataque do SSH (porta aberta, gestão de chaves, bastion hosts). O SSH continua suportado via `key_name` + regra de ingress na porta 22, mas é a opção menos segura.

---

## Ordem de criação dos recursos

```
data.aws_ami.al2023                          (se ami_id não informado)
        │
aws_kms_key.ec2 ─► aws_kms_alias.ec2          (se volume criptografado + create_kms_key)
        │
aws_security_group.ec2 ─► ingress/egress rules
        │
aws_iam_role.ec2 ─► attachments ─► aws_iam_instance_profile.ec2   (se create_iam_instance_profile)
        │
        └──────► aws_instance.main
                       │
                       ├─► aws_ebs_volume.additional ─► aws_volume_attachment.additional
                       │
                       └─► aws_eip.main               (se create_eip)
```

A instância depende do SG, do instance profile e da KMS key (resolvidos por referência). Os volumes adicionais e o EIP dependem da instância — daí virem depois no grafo.
