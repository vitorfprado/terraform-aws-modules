data "aws_partition" "current" {}

locals {
  cluster_role_arn         = var.create_cluster_iam_role ? aws_iam_role.cluster[0].arn : var.cluster_iam_role_arn
  control_plane_subnet_ids = distinct(concat(var.subnet_ids, var.control_plane_subnet_ids))

  create_node_role = var.create_node_iam_role && length(var.node_groups) > 0
  node_role_arn    = var.create_node_iam_role ? try(aws_iam_role.node[0].arn, null) : var.node_iam_role_arn

  enable_encryption  = var.create_kms_key || var.kms_key_arn != null
  encryption_key_arn = var.create_kms_key ? aws_kms_key.this[0].arn : var.kms_key_arn

  access_policy_associations = merge([
    for entry_key, entry in var.access_entries : {
      for assoc_key, assoc in entry.policy_associations :
      "${entry_key}/${assoc_key}" => {
        principal_arn = entry.principal_arn
        policy_arn    = assoc.policy_arn
        scope_type    = assoc.scope_type
        namespaces    = assoc.namespaces
      }
    }
  ]...)
}

resource "aws_cloudwatch_log_group" "this" {
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = var.cloudwatch_log_retention_in_days
  kms_key_id        = var.cloudwatch_log_kms_key_id
  tags              = var.tags
}

resource "aws_eks_cluster" "this" {
  name                      = var.cluster_name
  version                   = var.cluster_version
  role_arn                  = local.cluster_role_arn
  enabled_cluster_log_types = var.cluster_enabled_log_types

  access_config {
    authentication_mode                         = var.authentication_mode
    bootstrap_cluster_creator_admin_permissions = var.bootstrap_cluster_creator_admin_permissions
  }

  vpc_config {
    subnet_ids              = local.control_plane_subnet_ids
    endpoint_private_access = var.endpoint_private_access
    endpoint_public_access  = var.endpoint_public_access
    public_access_cidrs     = var.endpoint_public_access ? var.public_access_cidrs : null
    security_group_ids      = var.additional_security_group_ids
  }

  dynamic "encryption_config" {
    for_each = local.enable_encryption ? [1] : []
    content {
      resources = ["secrets"]
      provider {
        key_arn = local.encryption_key_arn
      }
    }
  }

  tags = var.tags

  depends_on = [
    aws_iam_role_policy_attachment.cluster,
    aws_cloudwatch_log_group.this,
  ]
}
