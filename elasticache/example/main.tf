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

module "elasticache" {
  source = "github.com/vitorfprado/terraform-aws-modules//elasticache?ref=main"

  name           = "${var.name}-cache"
  engine         = "redis"
  engine_version = "7.1"
  node_type      = "cache.t4g.micro"

  num_cache_clusters = 1

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids

  allowed_cidr_blocks = [module.vpc.vpc_cidr_block]

  at_rest_encryption_enabled = true

  tags = {
    Environment = "example"
    ManagedBy   = "terraform"
  }
}
