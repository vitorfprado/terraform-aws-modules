module "vpc" {
  source = "git::https://github.com/vitorfprado/terraform-aws-modules.git//vpc?ref=v1.1.0"

  name       = var.name
  cidr_block = var.cidr_block

  public_subnet_cidrs  = ["10.0.0.0/20", "10.0.16.0/20", "10.0.32.0/20"]
  private_subnet_cidrs = ["10.0.48.0/20", "10.0.64.0/20", "10.0.80.0/20"]

  enable_nat_gateway = true
  single_nat_gateway = true

  enable_s3_gateway_endpoint = true

  tags = {
    Environment = "example"
    ManagedBy   = "terraform"
  }
}
