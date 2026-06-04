# Explicação detalhada — módulo secrets-manager

Este documento percorre cada arquivo do módulo explicando **o que o código faz e por quê foi escrito assim**.

O Secrets Manager separa **metadados** do secret (nome, política de recuperação, KMS) do seu
**valor** (a versão). Por isso o módulo tem dois recursos: `aws_secretsmanager_secret` e
`aws_secretsmanager_secret_version`. Versionar o valor à parte é o que permite rotação sem
recriar o secret.

## Por que um módulo separado do `rds`

O módulo `rds` já sabe gerenciar a senha do master (`manage_master_user_password = true`),
mas o secret resultante tem **nome e formato definidos pela AWS** (`rds!db-...`, JSON com
`username`/`password`) — sem uma `connection_string` pronta e sem nome estável.

As aplicações deste projeto esperam um `DATABASE_URL` completo, e os manifestos do External
Secrets referenciam um **nome fixo** (`togglemaster/rds/auth`) com `property: connection_string`.
Para entregar isso é preciso um secret de nome e conteúdo controlados — papel deste módulo.
Mantê-lo separado evita inchar o `rds` com lógica de secret e permite usá-lo para qualquer
secret (API keys, tokens), não só de banco.

---

## `variables.tf`

### `secret_string` vs `secret_key_value`

```hcl
variable "secret_string"    { type = string,      default = null, sensitive = true }
variable "secret_key_value" { type = map(string), default = null, sensitive = true }
```

Duas formas de informar o conteúdo: uma string crua ou um mapa que vira JSON. Ambas são
`sensitive = true` para não vazarem em plan/output. A exclusividade entre as duas é validada
no `main.tf` (veja precondition). O mapa é o caso mais usado aqui — um secret de banco carrega
vários campos (`connection_string`, `host`, `username`…) e o External Secrets extrai um deles
por `property`.

---

## `main.tf`

### locals

```hcl
create_kms_key_resource = var.create_kms_key && var.kms_key_arn == null
kms_key_arn             = var.kms_key_arn != null ? var.kms_key_arn : (local.create_kms_key_resource ? aws_kms_key.secret[0].arn : null)
secret_value            = var.secret_key_value != null ? jsonencode(var.secret_key_value) : var.secret_string
```

A resolução de KMS é a mesma dos demais módulos (key informada > key criada > padrão do
serviço). O `secret_value` escolhe a fonte do conteúdo: se veio o mapa, serializa em JSON;
senão, usa a string. Quando `kms_key_arn` é `null`, o argumento `kms_key_id` do secret também
fica `null` e a AWS usa a key gerenciada `aws/secretsmanager` — o secret continua criptografado.

### A versão e a precondition

```hcl
resource "aws_secretsmanager_secret_version" "secret" {
  secret_id     = aws_secretsmanager_secret.secret.id
  secret_string = local.secret_value

  lifecycle {
    precondition {
      condition     = (var.secret_string == null) != (var.secret_key_value == null)
      error_message = "Informe exatamente um entre secret_string e secret_key_value."
    }
  }
}
```

A precondition usa um **XOR**: `(a == null) != (b == null)` só é verdadeiro quando exatamente
um dos dois está preenchido. Se ambos vierem nulos (nada a gravar) ou ambos preenchidos
(ambíguo), o plan falha com mensagem clara. Validação cruzada entre variáveis não cabe num
bloco `validation` (que só enxerga a própria variável), por isso fica aqui, no recurso.

---

## `kms.tf`

Mesma estrutura dos outros módulos: key dedicada com rotação automática, criada só quando
`create_kms_key = true` **e** nenhuma `kms_key_arn` foi passada. O alias segue o padrão
`alias/secretsmanager/<name>`. Sem isso, o Secrets Manager usa a key gerenciada padrão —
suficiente na maioria dos casos, sem custo extra de KMS.

---

## `outputs.tf`

O output mais usado é o `secret_name` — é a `key` que o External Secrets referencia no
`remoteRef`. O `secret_arn` serve para as políticas IAM (dar `secretsmanager:GetSecretValue`
à role do ESO) e o `version_id` ajuda a rastrear rotações.

---

## O valor no tfstate

O Terraform precisa do valor para criar a versão, então ele **fica no state**. Isso é
inerente a gerenciar secrets via Terraform — trate o state como sensível (backend remoto
criptografado, acesso restrito). A alternativa sem segredo no state é deixar a AWS gerenciar
a senha do RDS, abrindo mão da `connection_string` de nome fixo; é um trade-off consciente,
documentado no README.

---

## Ordem de criação dos recursos

```
aws_kms_key.secret ─► aws_kms_alias.secret        (se create_kms_key e sem kms_key_arn)
        │
aws_secretsmanager_secret.secret
        │
        └──► aws_secretsmanager_secret_version.secret
```

A versão depende do secret (onde gravar) e, indiretamente, da KMS key (com que criptografar).
O Terraform infere tudo por referência de atributo.
