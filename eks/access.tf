resource "aws_eks_access_entry" "principals" {
  for_each = var.access_entries

  cluster_name      = aws_eks_cluster.main.name
  principal_arn     = each.value.principal_arn
  type              = each.value.type
  kubernetes_groups = each.value.kubernetes_groups
  tags              = var.tags
}

resource "aws_eks_access_policy_association" "principals" {
  for_each = local.access_policy_associations

  cluster_name  = aws_eks_cluster.main.name
  principal_arn = each.value.principal_arn
  policy_arn    = each.value.policy_arn

  access_scope {
    type       = each.value.scope_type
    namespaces = each.value.scope_type == "namespace" ? each.value.namespaces : null
  }

  depends_on = [aws_eks_access_entry.principals]
}
