data "aws_partition" "current" {
  count = var.enable_karpenter ? 1 : 0
}

data "aws_caller_identity" "current" {
  count = var.enable_karpenter ? 1 : 0
}

data "aws_region" "current" {
  count = var.enable_karpenter ? 1 : 0
}

locals {
  karpenter_events = var.enable_karpenter ? {
    spot_interruption = {
      detail_type = "EC2 Spot Instance Interruption Warning"
      source      = "aws.ec2"
    }
    rebalance = {
      detail_type = "EC2 Instance Rebalance Recommendation"
      source      = "aws.ec2"
    }
    instance_state_change = {
      detail_type = "EC2 Instance State-change Notification"
      source      = "aws.ec2"
    }
    scheduled_change = {
      detail_type = "AWS Health Event"
      source      = "aws.health"
    }
  } : {}
}

data "aws_iam_policy_document" "karpenter_node_assume" {
  count = var.enable_karpenter ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "karpenter_node" {
  count = var.enable_karpenter ? 1 : 0

  name_prefix        = "${var.cluster_name}-karpenter-node-"
  assume_role_policy = data.aws_iam_policy_document.karpenter_node_assume[0].json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "karpenter_node" {
  for_each = var.enable_karpenter ? toset([
    "arn:${data.aws_partition.current[0].partition}:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:${data.aws_partition.current[0].partition}:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:${data.aws_partition.current[0].partition}:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "arn:${data.aws_partition.current[0].partition}:iam::aws:policy/AmazonSSMManagedInstanceCore",
  ]) : []

  role       = aws_iam_role.karpenter_node[0].name
  policy_arn = each.value
}

resource "aws_eks_access_entry" "karpenter_node" {
  count = var.enable_karpenter ? 1 : 0

  cluster_name  = var.cluster_name
  principal_arn = aws_iam_role.karpenter_node[0].arn
  type          = "EC2_LINUX"
  tags          = var.tags
}

resource "aws_sqs_queue" "karpenter" {
  count = var.enable_karpenter ? 1 : 0

  name                      = "${var.cluster_name}-karpenter"
  message_retention_seconds = 300
  sqs_managed_sse_enabled   = true
  tags                      = var.tags
}

data "aws_iam_policy_document" "karpenter_queue" {
  count = var.enable_karpenter ? 1 : 0

  statement {
    sid       = "EC2InterruptionPolicy"
    effect    = "Allow"
    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.karpenter[0].arn]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com", "sqs.amazonaws.com"]
    }
  }
}

resource "aws_sqs_queue_policy" "karpenter" {
  count = var.enable_karpenter ? 1 : 0

  queue_url = aws_sqs_queue.karpenter[0].url
  policy    = data.aws_iam_policy_document.karpenter_queue[0].json
}

resource "aws_cloudwatch_event_rule" "karpenter" {
  for_each = local.karpenter_events

  name_prefix = "${var.cluster_name}-karpenter-"
  event_pattern = jsonencode({
    source      = [each.value.source]
    detail-type = [each.value.detail_type]
  })
  tags = var.tags
}

resource "aws_cloudwatch_event_target" "karpenter" {
  for_each = local.karpenter_events

  rule      = aws_cloudwatch_event_rule.karpenter[each.key].name
  target_id = "KarpenterInterruptionQueue"
  arn       = aws_sqs_queue.karpenter[0].arn
}

data "aws_iam_policy_document" "karpenter_controller_assume" {
  count = var.enable_karpenter ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider_url}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider_url}:sub"
      values   = ["system:serviceaccount:${var.karpenter_namespace}:karpenter"]
    }
  }
}

resource "aws_iam_role" "karpenter_controller" {
  count = var.enable_karpenter ? 1 : 0

  name_prefix        = "${var.cluster_name}-karpenter-"
  assume_role_policy = data.aws_iam_policy_document.karpenter_controller_assume[0].json
  tags               = var.tags
}

resource "aws_iam_policy" "karpenter_controller" {
  count = var.enable_karpenter ? 1 : 0

  name_prefix = "${var.cluster_name}-karpenter-"
  description = "Permissões do controller Karpenter para o cluster ${var.cluster_name}"
  policy = templatefile("${path.module}/policies/karpenter_controller_iam_policy.json.tftpl", {
    partition              = data.aws_partition.current[0].partition
    region                 = coalesce(var.region, data.aws_region.current[0].region)
    account_id             = data.aws_caller_identity.current[0].account_id
    cluster_name           = var.cluster_name
    node_role_arn          = aws_iam_role.karpenter_node[0].arn
    interruption_queue_arn = aws_sqs_queue.karpenter[0].arn
  })
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "karpenter_controller" {
  count = var.enable_karpenter ? 1 : 0

  role       = aws_iam_role.karpenter_controller[0].name
  policy_arn = aws_iam_policy.karpenter_controller[0].arn
}

resource "helm_release" "karpenter" {
  count = var.enable_karpenter ? 1 : 0

  name       = "karpenter"
  namespace  = var.karpenter_namespace
  repository = "oci://public.ecr.aws/karpenter"
  chart      = "karpenter"
  version    = var.karpenter_chart_version

  set = [
    { name = "settings.clusterName", value = var.cluster_name },
    { name = "settings.interruptionQueue", value = aws_sqs_queue.karpenter[0].name },
    { name = "serviceAccount.name", value = "karpenter" },
    { name = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn", value = aws_iam_role.karpenter_controller[0].arn },
  ]

  values = var.karpenter_helm_values

  depends_on = [
    aws_iam_role_policy_attachment.karpenter_controller,
    aws_eks_access_entry.karpenter_node,
  ]
}
