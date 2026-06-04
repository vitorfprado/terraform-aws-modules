# Exemplo — secrets-manager

Cria dois secrets:

- `rds_secret` — secret **multi-campo** (JSON com `connection_string`, `host`, `username`…), o caso típico consumido pelo External Secrets via `property: connection_string`.
- `api_key_secret` — secret de **string única**.

## Uso

```bash
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan
terraform apply
```

O `rds_secret` fica acessível ao External Secrets assim:

```yaml
data:
  - secretKey: DATABASE_URL
    remoteRef:
      key: togglemaster/rds/auth   # = module.rds_secret.secret_name
      property: connection_string
```

> Em uso real, gere a senha com `random_password` no consumer em vez de passá-la
> como variável.
