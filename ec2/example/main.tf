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

module "ec2" {
  source = "github.com/vitorfprado/terraform-aws-modules//ec2?ref=main"

  name          = var.name
  instance_type = "t3.micro"

  vpc_id    = module.vpc.vpc_id
  subnet_id = module.vpc.private_subnet_ids[0]

  # Acesso via SSM Session Manager: sem chave SSH, sem IP público, sem porta aberta.
  create_iam_instance_profile = true
  iam_role_policy_arns = {
    ssm = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  tags = {
    Environment = "example"
    ManagedBy   = "terraform"
  }
}
