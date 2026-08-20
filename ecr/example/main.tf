module "ecr" {
  source = "github.com/fiap-tech-challenge-devops/terraform-aws-modules//ecr?ref=main"

  namespace = var.namespace

  repository_names = [
    "auth-service",
    "flag-service",
    "targeting-service",
    "evaluation-service",
    "analytics-service",
  ]

  # Tags derivadas do commit nunca são reaproveitadas — imutabilidade garante
  # que a imagem auditada na esteira é a mesma que roda no cluster.
  image_tag_mutability = "IMMUTABLE"
  scan_on_push         = true

  # Sem lifecycle policy, cada build acumula uma imagem cobrada para sempre.
  untagged_image_expiration_days = 7
  max_tagged_images              = 30

  create_ssm_parameters = true

  tags = {
    Environment = "example"
    ManagedBy   = "terraform"
  }
}
