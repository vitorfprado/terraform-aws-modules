resource "aws_eks_node_group" "managed" {
  for_each = var.node_groups

  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.cluster_name}-${each.key}"
  node_role_arn   = local.node_role_arn
  subnet_ids      = length(each.value.subnet_ids) > 0 ? each.value.subnet_ids : var.subnet_ids
  version         = var.cluster_version

  ami_type       = each.value.ami_type
  capacity_type  = each.value.capacity_type
  instance_types = each.value.instance_types
  disk_size      = each.value.disk_size
  labels         = each.value.labels

  scaling_config {
    desired_size = each.value.desired_size
    min_size     = each.value.min_size
    max_size     = each.value.max_size
  }

  dynamic "taint" {
    for_each = each.value.taints
    content {
      key    = taint.value.key
      value  = taint.value.value
      effect = taint.value.effect
    }
  }

  dynamic "update_config" {
    for_each = each.value.max_unavailable != null || each.value.max_unavailable_percentage != null ? [1] : []
    content {
      max_unavailable            = each.value.max_unavailable
      max_unavailable_percentage = each.value.max_unavailable_percentage
    }
  }

  tags = merge(var.tags, each.value.tags)

  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }

  depends_on = [
    aws_iam_role_policy_attachment.node,
    aws_iam_role_policy_attachment.node_additional,
  ]
}
