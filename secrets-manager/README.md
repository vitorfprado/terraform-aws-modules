# Módulo Terraform – Secrets Manager

Cria um secret no AWS Secrets Manager (`aws_secretsmanager_secret` + versão), aceitando
conteúdo como **string única** ou como **mapa key/value** serializado em JSON, com KMS
opcional (key dedicada ou a gerenciada do serviço).

É o complemento natural do módulo `rds`: o RDS guarda o endereço/porta, e este módulo
publica a **connection string** num secret de nome fixo que o External Secrets Operator
sincroniza para dentro do cluster.

> Cada secret é uma chamada do módulo. Para vários secrets (ex.: três bancos), chame o
> módulo várias vezes no consumer (ou via `for_each`).

## Recursos criados

- `aws_secretsmanager_secret` – o secret (metadados, política de recuperação, KMS)
- `aws_secretsmanager_secret_version` – o valor atual do secret
- `aws_kms_key` / `aws_kms_alias` – criptografia com key dedicada (opcional)

## Uso

Secret multi-campo (consumido por `property` no External Secrets):

```hcl
module "rds_secret" {
  source = "github.com/vitorfprado/terraform-aws-modules//secrets-manager?ref=main"

  name = "togglemaster/rds/auth"

  secret_key_value = {
    connection_string = "postgres://auth_user:${random_password.auth.result}@${module.rds.db_instance_address}:5432/auth_db?sslmode=require"
    host              = module.rds.db_instance_address
    username          = "auth_user"
    password          = random_password.auth.result
  }

  recovery_window_in_days = 0 # lab — exclui na hora

  tags = { Service = "auth-service" }
}
```

Secret de string única:

```hcl
module "api_key" {
  source = "github.com/vitorfprado/terraform-aws-modules//secrets-manager?ref=main"

  name          = "togglemaster/evaluation/api-key"
  secret_string = random_password.api_key.result
}
```

Um exemplo completo e copiável está em [`example/`](./example).

## String única vs mapa key/value

Informe **exatamente um** entre `secret_string` e `secret_key_value` (o módulo valida isso):

- **`secret_string`** — grava o valor cru. Bom para um token/chave único.
- **`secret_key_value`** — `map(string)` que vira JSON. Bom para secrets multi-campo. O
  External Secrets extrai um campo via `property` (ex.: `property: connection_string`).

## Consumo pelo External Secrets

```yaml
apiVersion: external-secrets.io/v1
kind: ExternalSecret
spec:
  secretStoreRef:
    name: aws-secrets-manager
    kind: ClusterSecretStore
  data:
    - secretKey: DATABASE_URL
      remoteRef:
        key: togglemaster/rds/auth   # = output secret_name
        property: connection_string  # campo do secret_key_value
```

## Criptografia

Por padrão o secret usa a key gerenciada do serviço (`aws/secretsmanager`) — sem custo
adicional de KMS. Com `create_kms_key = true`, o módulo cria uma key dedicada (com rotação);
ou informe `kms_key_arn` para reusar uma existente.

## Requisitos

| Nome      | Versão   |
|-----------|----------|
| terraform | >= 1.5   |
| aws       | >= 5.40  |

## Variáveis de entrada

| Nome | Descrição | Tipo | Padrão | Obrigatória |
|------|-----------|------|--------|:-----------:|
| `name` | Nome do secret (ex.: togglemaster/rds/auth). | `string` | — | sim |
| `description` | Descrição (null = gerada do name). | `string` | `null` | não |
| `secret_string` | Conteúdo como string única. | `string` | `null` | não¹ |
| `secret_key_value` | Conteúdo como mapa → JSON. | `map(string)` | `null` | não¹ |
| `recovery_window_in_days` | Janela de recuperação (0 = exclui na hora). | `number` | `30` | não |
| `create_kms_key` | Cria KMS key dedicada. | `bool` | `false` | não |
| `kms_key_arn` | KMS key existente. | `string` | `null` | não |
| `kms_key_deletion_window_in_days` | Janela de exclusão da KMS key. | `number` | `30` | não |
| `tags` | Tags aplicadas a todos os recursos. | `map(string)` | `{}` | não |

¹ Informe exatamente um entre `secret_string` e `secret_key_value`.

## Outputs

| Nome | Descrição |
|------|-----------|
| `secret_arn` | ARN do secret (IAM e remoteRef). |
| `secret_id` | ID do secret. |
| `secret_name` | Nome do secret (key do remoteRef). |
| `version_id` | ID da versão atual. |
| `kms_key_arn` | ARN da KMS key dedicada, quando criada. |

## Nota sobre o tfstate

O valor do secret entra no **tfstate** (o Terraform precisa dele para criar a versão). Trate
o state como sensível (backend remoto criptografado). Como alternativa, deixe o RDS gerenciar
a própria senha (`manage_master_user_password = true` no módulo `rds`) — mas aí o secret tem
formato/nome gerenciados pela AWS, sem uma `connection_string` pronta.
