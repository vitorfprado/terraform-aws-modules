locals {
  create_kms_key_resource = var.at_rest_encryption_enabled && var.create_kms_key && var.kms_key_arn == null
  kms_key_arn             = var.kms_key_arn != null ? var.kms_key_arn : (local.create_kms_key_resource ? aws_kms_key.elasticache[0].arn : null)

  security_group_ids = var.create_security_group ? concat([aws_security_group.elasticache[0].id], var.vpc_security_group_ids) : var.vpc_security_group_ids

  parameter_group_name = var.create_parameter_group ? aws_elasticache_parameter_group.elasticache[0].name : var.parameter_group_name
}

resource "aws_elasticache_subnet_group" "main" {
  name       = var.name
  subnet_ids = var.subnet_ids

  tags = merge(var.tags, { Name = var.name })
}

resource "aws_elasticache_replication_group" "main" {
  replication_group_id = var.name
  description          = coalesce(var.description, "Replication group ${var.name}")

  engine         = var.engine
  engine_version = var.engine_version
  node_type      = var.node_type
  port           = var.port

  parameter_group_name = local.parameter_group_name

  num_cache_clusters      = var.cluster_mode_enabled ? null : var.num_cache_clusters
  num_node_groups         = var.cluster_mode_enabled ? var.num_node_groups : null
  replicas_per_node_group = var.cluster_mode_enabled ? var.replicas_per_node_group : null

  automatic_failover_enabled = var.cluster_mode_enabled ? true : var.automatic_failover_enabled
  multi_az_enabled           = var.multi_az_enabled

  subnet_group_name  = aws_elasticache_subnet_group.main.name
  security_group_ids = local.security_group_ids

  at_rest_encryption_enabled = var.at_rest_encryption_enabled
  kms_key_id                 = var.at_rest_encryption_enabled ? local.kms_key_arn : null
  transit_encryption_enabled = var.transit_encryption_enabled
  auth_token                 = var.transit_encryption_enabled ? var.auth_token : null

  snapshot_retention_limit   = var.snapshot_retention_limit
  snapshot_window            = var.snapshot_window
  maintenance_window         = var.maintenance_window
  apply_immediately          = var.apply_immediately
  auto_minor_version_upgrade = var.auto_minor_version_upgrade

  dynamic "log_delivery_configuration" {
    for_each = var.log_delivery_configuration
    content {
      destination      = log_delivery_configuration.value.destination
      destination_type = log_delivery_configuration.value.destination_type
      log_format       = log_delivery_configuration.value.log_format
      log_type         = log_delivery_configuration.value.log_type
    }
  }

  tags = merge(var.tags, { Name = var.name })
}
