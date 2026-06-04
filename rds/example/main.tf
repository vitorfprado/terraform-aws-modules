module "vpc" {
  source = "github.com/vitorfprado/terraform-aws-modules//vpc?ref=main"

  name       = "${var.name}-vpc"
  cidr_block = "10.0.0.0/16"

  public_subnet_cidrs  = ["10.0.0.0/20", "10.0.16.0/20", "10.0.32.0/20"]
  private_subnet_cidrs = ["10.0.48.0/20", "10.0.64.0/20", "10.0.80.0/20"]

  enable_nat_gateway = true
  single_nat_gateway = true

  tags = {
    Environment = "example"
    ManagedBy   = "terraform"
  }
}

module "rds" {
  source = "github.com/vitorfprado/terraform-aws-modules//rds?ref=main"

  name           = var.name
  engine         = "postgres"
  engine_version = "16"
  instance_class = "db.t3.micro"

  allocated_storage = 20

  db_name  = "appdb"
  username = "appuser"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids

  allowed_cidr_blocks = [module.vpc.vpc_cidr_block]

  # Valores apenas para facilitar testes no exemplo.
  # Em produção, mantenha os defaults (deletion_protection = true, skip_final_snapshot = false).
  multi_az            = false
  deletion_protection = false
  skip_final_snapshot = true

  tags = {
    Environment = "example"
    ManagedBy   = "terraform"
  }
}
