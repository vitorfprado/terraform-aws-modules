# Módulo Terraform – EC2

Provisiona uma instância EC2 com security group dedicado, IAM instance profile opcional, volumes EBS criptografados, IMDSv2 forçado e Elastic IP opcional. Por padrão, faz o lookup automático da AMI mais recente do Amazon Linux 2023.

Como o RDS, é um recurso de VPC: recebe `vpc_id` e `subnet_id` como entrada e não cria a rede. Para múltiplas instâncias, chame o módulo várias vezes no consumer.

## Recursos criados

- `aws_instance` – a instância EC2
- `aws_security_group` + regras – controle de acesso (opcional)
- `aws_iam_role` / `aws_iam_instance_profile` – perfil da instância (opcional)
- `aws_ebs_volume` / `aws_volume_attachment` – volumes adicionais (opcional)
- `aws_eip` – Elastic IP (opcional)
- `aws_kms_key` / `aws_kms_alias` – criptografia dos volumes com key dedicada (opcional)

## Uso

```hcl
module "app_server" {
  source = "github.com/fiap-tech-challenge-devops/terraform-aws-modules//ec2?ref=main"

  name          = "app-server"
  instance_type = "t3.small"

  vpc_id    = module.vpc.vpc_id
  subnet_id = module.vpc.private_subnet_ids[0]

  create_iam_instance_profile = true
  iam_role_policy_arns = {
    ssm = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  tags = {
    Environment = "producao"
  }
}
```

Servidor web público com Elastic IP e regras de entrada:

```hcl
module "web" {
  source = "github.com/fiap-tech-challenge-devops/terraform-aws-modules//ec2?ref=main"

  name          = "web"
  instance_type = "t3.micro"

  vpc_id    = module.vpc.vpc_id
  subnet_id = module.vpc.public_subnet_ids[0]

  associate_public_ip_address = true
  create_eip                  = true

  ingress_rules = [
    { from_port = 80, to_port = 80, cidr_ipv4 = "0.0.0.0/0", description = "HTTP" },
    { from_port = 443, to_port = 443, cidr_ipv4 = "0.0.0.0/0", description = "HTTPS" },
  ]
}
```

Um exemplo completo e copiável (VPC + EC2 com acesso via SSM) está em [`example/`](./example).

## AMI

Quando `ami_id` não é informado, o módulo busca a Amazon Linux 2023 mais recente para a arquitetura em `ami_architecture` (`x86_64` por padrão). Para instâncias Graviton (ex.: `t4g`, `m7g`), defina `ami_architecture = "arm64"`. Para usar outra imagem, informe `ami_id` diretamente.

## Acesso à instância

Duas abordagens:

- **SSM Session Manager (recomendado)** — sem chave SSH, sem porta aberta, sem IP público. Crie o instance profile com a política `AmazonSSMManagedInstanceCore` (ver exemplo) e conecte com `aws ssm start-session`. Requer saída para a internet (NAT) ou VPC endpoints do SSM.
- **SSH** — informe `key_name` e abra a porta 22 em `ingress_rules`. Menos seguro; prefira SSM.

## Segurança

- **IMDSv2 forçado** (`metadata_http_tokens = "required"`) por padrão, mitigando ataques de SSRF ao metadata service. Para instâncias que rodam containers acessando o metadata, pode ser necessário `metadata_http_put_response_hop_limit = 2`.
- **Volumes criptografados** por padrão (`root_volume_encrypted = true`), com a key padrão `aws/ebs` ou uma KMS key dedicada (`create_kms_key`/`kms_key_arn`).

## Requisitos

| Nome      | Versão   |
|-----------|----------|
| terraform | >= 1.5   |
| aws       | >= 5.40  |

## Variáveis de entrada

| Nome | Descrição | Tipo | Padrão | Obrigatória |
|------|-----------|------|--------|:-----------:|
| `name` | Nome da instância e prefixo. | `string` | — | sim |
| `vpc_id` | VPC onde o SG é criado. | `string` | — | sim |
| `subnet_id` | Subnet onde a instância roda. | `string` | — | sim |
| `ami_id` | AMI explícita (null = lookup AL2023). | `string` | `null` | não |
| `ami_architecture` | Arquitetura do lookup (x86_64/arm64). | `string` | `"x86_64"` | não |
| `instance_type` | Tipo da instância. | `string` | `"t3.micro"` | não |
| `key_name` | Key pair SSH. | `string` | `null` | não |
| `user_data` | Script de inicialização. | `string` | `null` | não |
| `user_data_replace_on_change` | Recria instância ao mudar user_data. | `bool` | `false` | não |
| `associate_public_ip_address` | IP público. | `bool` | `false` | não |
| `create_eip` | Cria Elastic IP. | `bool` | `false` | não |
| `monitoring` | Detailed monitoring. | `bool` | `false` | não |
| `metadata_http_tokens` | IMDSv2 (`required`) ou IMDSv1 (`optional`). | `string` | `"required"` | não |
| `metadata_http_put_response_hop_limit` | Limite de saltos do metadata. | `number` | `1` | não |
| `create_security_group` | Cria SG dedicado. | `bool` | `true` | não |
| `vpc_security_group_ids` | SGs existentes adicionais. | `list(string)` | `[]` | não |
| `ingress_rules` | Regras de entrada do SG. | `list(object)` | `[]` | não |
| `create_iam_instance_profile` | Cria role + instance profile. | `bool` | `false` | não |
| `iam_role_policy_arns` | Políticas a anexar (mapa). | `map(string)` | `{}` | não |
| `iam_instance_profile` | Instance profile existente. | `string` | `null` | não |
| `root_volume_size` | Tamanho do volume raiz (GB). | `number` | `20` | não |
| `root_volume_type` | Tipo do volume raiz. | `string` | `"gp3"` | não |
| `root_volume_encrypted` | Criptografa o volume raiz. | `bool` | `true` | não |
| `ebs_volumes` | Volumes EBS adicionais. | `list(object)` | `[]` | não |
| `create_kms_key` | Cria KMS key dedicada. | `bool` | `false` | não |
| `kms_key_arn` | KMS key existente. | `string` | `null` | não |
| `kms_key_deletion_window_in_days` | Janela de exclusão da KMS key. | `number` | `30` | não |
| `tags` | Tags aplicadas a todos os recursos. | `map(string)` | `{}` | não |

### Estrutura de `ingress_rules`

```hcl
ingress_rules = [
  {
    description                  = "HTTP"     # opcional
    from_port                    = 80
    to_port                      = 80
    ip_protocol                  = "tcp"      # padrão "tcp"
    cidr_ipv4                    = "0.0.0.0/0" # informe isto OU o referenced_security_group_id
    referenced_security_group_id = null
  }
]
```

### Estrutura de `ebs_volumes`

```hcl
ebs_volumes = [
  {
    device_name = "/dev/sdf"
    size        = 100
    type        = "gp3"   # padrão "gp3"
    iops        = null    # opcional
    throughput  = null    # opcional
    encrypted   = true    # padrão true
  }
]
```

## Outputs

| Nome | Descrição |
|------|-----------|
| `instance_id` | ID da instância. |
| `instance_arn` | ARN da instância. |
| `availability_zone` | AZ da instância. |
| `private_ip` | IP privado. |
| `public_ip` | IP público (EIP ou efêmero). |
| `private_dns` | DNS privado. |
| `security_group_id` | ID do security group criado. |
| `iam_role_arn` | ARN da role da instância. |
| `iam_role_name` | Nome da role da instância. |
| `instance_profile_name` | Instance profile em uso. |
| `kms_key_arn` | ARN da KMS key dedicada, quando criada. |
