module "vpc" {
  source = "github.com/fiap-tech-challenge-devops/terraform-aws-modules//vpc?ref=main"

  name       = "${var.cluster_name}-vpc"
  cidr_block = "10.0.0.0/16"

  public_subnet_cidrs  = ["10.0.0.0/20", "10.0.16.0/20", "10.0.32.0/20"]
  private_subnet_cidrs = ["10.0.48.0/20", "10.0.64.0/20", "10.0.80.0/20"]

  enable_nat_gateway = true
  single_nat_gateway = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }

  # O Karpenter descobre subnets e security groups por tag. Sem karpenter.sh/discovery
  # o EC2NodeClass não encontra onde lançar os nós.
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
    "karpenter.sh/discovery"          = var.cluster_name
  }

  tags = {
    Environment = "example"
    ManagedBy   = "terraform"
  }
}

module "eks" {
  source = "github.com/fiap-tech-challenge-devops/terraform-aws-modules//eks?ref=main"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids

  enable_irsa = true

  # Node group mínimo, de baseline: o controller do Karpenter precisa de um nó
  # para rodar antes de conseguir provisionar qualquer outro.
  node_groups = {
    baseline = {
      instance_types = ["t3.medium"]
      capacity_type  = "ON_DEMAND"
      desired_size   = 1
      min_size       = 1
      max_size       = 2
    }
  }

  cluster_addons = {
    coredns    = {}
    kube-proxy = {}
    vpc-cni    = {}
  }

  tags = {
    Environment = "example"
    ManagedBy   = "terraform"
  }
}

module "karpenter" {
  source = "github.com/fiap-tech-challenge-devops/terraform-aws-modules//eks-karpenter?ref=main"

  cluster_name      = module.eks.cluster_name
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url
  region            = var.region

  create_ssm_parameters = true

  tags = {
    Environment = "example"
    ManagedBy   = "terraform"
  }
}
