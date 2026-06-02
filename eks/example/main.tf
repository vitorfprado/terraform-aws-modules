module "eks" {
  source = "../"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id     = var.vpc_id
  subnet_ids = var.subnet_ids

  endpoint_private_access = true
  endpoint_public_access  = true
  public_access_cidrs     = ["0.0.0.0/0"]

  enable_irsa    = true
  create_kms_key = true

  node_groups = {
    general = {
      instance_types = ["t3.medium"]
      capacity_type  = "ON_DEMAND"
      desired_size   = 2
      min_size       = 1
      max_size       = 4
      labels = {
        role = "general"
      }
    }

    spot = {
      instance_types = ["t3.large", "t3a.large"]
      capacity_type  = "SPOT"
      desired_size   = 1
      min_size       = 0
      max_size       = 5
      labels = {
        role = "spot"
      }
      taints = [{
        key    = "spot"
        value  = "true"
        effect = "NO_SCHEDULE"
      }]
    }
  }

  cluster_addons = {
    coredns                = {}
    kube-proxy             = {}
    vpc-cni                = {}
    eks-pod-identity-agent = {}
  }

  access_entries = {
    admin = {
      principal_arn = var.admin_role_arn
      policy_associations = {
        cluster_admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          scope_type = "cluster"
        }
      }
    }
  }

  tags = {
    Environment = "example"
    ManagedBy   = "terraform"
  }
}

module "addons" {
  source = "../addons"

  cluster_name      = module.eks.cluster_name
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url
  vpc_id            = var.vpc_id
  region            = var.region

  enable_metrics_server               = var.enable_metrics_server
  enable_aws_load_balancer_controller = var.enable_aws_load_balancer_controller
  enable_cert_manager                 = var.enable_cert_manager
  enable_external_secrets             = var.enable_external_secrets
  enable_kube_prometheus_stack        = var.enable_kube_prometheus_stack
  enable_argocd                       = var.enable_argocd

  tags = {
    Environment = "example"
    ManagedBy   = "terraform"
  }

  depends_on = [module.eks]
}
