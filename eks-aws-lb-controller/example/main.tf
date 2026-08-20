module "vpc" {
  source = "github.com/fiap-tech-challenge-devops/terraform-aws-modules//vpc?ref=main"

  name       = "${var.cluster_name}-vpc"
  cidr_block = "10.0.0.0/16"

  public_subnet_cidrs  = ["10.0.0.0/20", "10.0.16.0/20", "10.0.32.0/20"]
  private_subnet_cidrs = ["10.0.48.0/20", "10.0.64.0/20", "10.0.80.0/20"]

  enable_nat_gateway = true
  single_nat_gateway = true

  # O controller descobre onde criar o ALB por estas tags. Sem elas, o Ingress
  # fica pendente com "unable to discover subnets".
  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
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

  node_groups = {
    general = {
      instance_types = ["t3.medium"]
      capacity_type  = "ON_DEMAND"
      desired_size   = 2
      min_size       = 1
      max_size       = 4
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

module "lb_controller" {
  source = "github.com/fiap-tech-challenge-devops/terraform-aws-modules//eks-aws-lb-controller?ref=main"

  cluster_name      = module.eks.cluster_name
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url
  vpc_id            = module.vpc.vpc_id
  region            = var.region

  create_ssm_parameters = true

  tags = {
    Environment = "example"
    ManagedBy   = "terraform"
  }
}
