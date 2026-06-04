module "vpc" {
  source = "github.com/vitorfprado/terraform-aws-modules//vpc?ref=main"

  name       = "${var.cluster_name}-vpc"
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

module "eks" {
  source = "github.com/vitorfprado/terraform-aws-modules//eks?ref=main"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids

  endpoint_public_access = true
  enable_irsa            = true

  node_groups = {
    general = {
      instance_types = ["t3.medium"]
      desired_size   = 2
      min_size       = 1
      max_size       = 3
    }
  }

  tags = {
    Environment = "example"
    ManagedBy   = "terraform"
  }
}

# Permissões da role (analytics-service: consome SQS e grava no DynamoDB).
data "aws_iam_policy_document" "analytics" {
  statement {
    effect    = "Allow"
    actions   = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"]
    resources = ["*"]
  }

  statement {
    effect    = "Allow"
    actions   = ["dynamodb:PutItem"]
    resources = ["*"]
  }
}

# IRSA com policy inline + publicação do ARN no SSM.
module "irsa_analytics" {
  source = "github.com/vitorfprado/terraform-aws-modules//iam-irsa?ref=main"

  name              = "${var.cluster_name}-analytics"
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url

  namespace        = "togglemaster"
  service_accounts = ["analytics-service"]

  policy_json = data.aws_iam_policy_document.analytics.json

  create_ssm_parameter = true

  tags = {
    Environment = "example"
    Service     = "analytics-service"
  }
}

# IRSA apenas com managed policy (somente leitura no S3, como exemplo).
module "irsa_readonly" {
  source = "github.com/vitorfprado/terraform-aws-modules//iam-irsa?ref=main"

  name              = "${var.cluster_name}-readonly"
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url

  namespace        = "togglemaster"
  service_accounts = ["reporting-service"]

  policy_arns = ["arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"]

  tags = {
    Environment = "example"
  }
}
