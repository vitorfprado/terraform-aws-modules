resource "aws_eks_addon" "this" {
  for_each = var.cluster_addons

  cluster_name = aws_eks_cluster.this.name
  addon_name   = each.key

  addon_version               = each.value.version
  service_account_role_arn    = each.value.service_account_role_arn
  configuration_values        = each.value.configuration_values
  preserve                    = each.value.preserve
  resolve_conflicts_on_create = each.value.resolve_conflicts_on_create
  resolve_conflicts_on_update = each.value.resolve_conflicts_on_update

  tags = var.tags

  depends_on = [aws_eks_node_group.this]
}
