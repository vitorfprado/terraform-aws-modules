# Secret multi-campo (JSON) — o caso típico de connection string consumida pelo
# External Secrets via property.
module "rds_secret" {
  source = "github.com/vitorfprado/terraform-aws-modules//secrets-manager?ref=main"

  name        = "togglemaster/rds/auth"
  description = "Credenciais RDS do auth-service"

  secret_key_value = {
    connection_string = "postgres://auth_user:${var.db_password}@db.example.internal:5432/auth_db?sslmode=require"
    host              = "db.example.internal"
    port              = "5432"
    database          = "auth_db"
    username          = "auth_user"
    password          = var.db_password
  }

  recovery_window_in_days = 0

  tags = {
    Environment = "example"
    Service     = "auth-service"
  }
}

# Secret de string única (ex.: uma API key).
module "api_key_secret" {
  source = "github.com/vitorfprado/terraform-aws-modules//secrets-manager?ref=main"

  name          = "togglemaster/evaluation/api-key"
  secret_string = var.api_key

  recovery_window_in_days = 0

  tags = {
    Environment = "example"
  }
}
