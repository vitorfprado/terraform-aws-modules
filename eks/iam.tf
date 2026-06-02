data "aws_iam_policy_document" "cluster_assume" {
  count = var.create_cluster_iam_role ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cluster" {
  count = var.create_cluster_iam_role ? 1 : 0

  name_prefix        = "${var.cluster_name}-cluster-"
  assume_role_policy = data.aws_iam_policy_document.cluster_assume[0].json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "cluster" {
  for_each = var.create_cluster_iam_role ? toset([
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKSClusterPolicy",
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKSVPCResourceController",
  ]) : []

  role       = aws_iam_role.cluster[0].name
  policy_arn = each.value
}

data "aws_iam_policy_document" "node_assume" {
  count = local.create_node_role ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "node" {
  count = local.create_node_role ? 1 : 0

  name_prefix        = "${var.cluster_name}-node-"
  assume_role_policy = data.aws_iam_policy_document.node_assume[0].json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "node" {
  for_each = local.create_node_role ? toset([
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore",
  ]) : []

  role       = aws_iam_role.node[0].name
  policy_arn = each.value
}

resource "aws_iam_role_policy_attachment" "node_additional" {
  for_each = local.create_node_role ? var.node_iam_role_additional_policies : {}

  role       = aws_iam_role.node[0].name
  policy_arn = each.value
}
