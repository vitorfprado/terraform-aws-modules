# Role assumida pelas instâncias EC2 que o Karpenter provisiona. Não é IRSA:
# o principal é o serviço ec2, não o OIDC do cluster.
data "aws_iam_policy_document" "node_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.${data.aws_partition.current.dns_suffix}"]
    }
  }
}

resource "aws_iam_role" "node" {
  name                 = local.node_role_name
  assume_role_policy   = data.aws_iam_policy_document.node_assume.json
  max_session_duration = var.node_role_max_session_duration

  tags = merge(var.tags, { Name = local.node_role_name })
}

# As quatro policies que todo nó EKS precisa: registrar-se no cluster, operar o
# CNI, puxar imagens do ECR e aceitar sessões do SSM.
resource "aws_iam_role_policy_attachment" "node_required" {
  for_each = toset([
    "AmazonEKSWorkerNodePolicy",
    "AmazonEKS_CNI_Policy",
    "AmazonEC2ContainerRegistryReadOnly",
    "AmazonSSMManagedInstanceCore",
  ])

  role       = aws_iam_role.node.name
  policy_arn = "arn:${local.partition}:iam::aws:policy/${each.value}"
}

resource "aws_iam_role_policy_attachment" "node_additional" {
  for_each = var.node_role_additional_policy_arns

  role       = aws_iam_role.node.name
  policy_arn = each.value
}

# Sem o access entry, os nós autenticam na API do cluster mas não são
# autorizados — ficam presos em NotReady.
resource "aws_eks_access_entry" "node" {
  count = var.create_node_access_entry ? 1 : 0

  cluster_name  = var.cluster_name
  principal_arn = aws_iam_role.node.arn
  type          = "EC2_LINUX"

  tags = var.tags
}
