locals {
  is_provisioned = var.billing_mode == "PROVISIONED"

  create_kms_key_resource = var.server_side_encryption_enabled && var.create_kms_key && var.kms_key_arn == null
  kms_key_arn             = var.kms_key_arn != null ? var.kms_key_arn : (local.create_kms_key_resource ? aws_kms_key.dynamodb[0].arn : null)
}

resource "aws_dynamodb_table" "main" {
  name         = var.name
  billing_mode = var.billing_mode
  hash_key     = var.hash_key
  range_key    = var.range_key

  read_capacity  = local.is_provisioned ? var.read_capacity : null
  write_capacity = local.is_provisioned ? var.write_capacity : null

  table_class                 = var.table_class
  deletion_protection_enabled = var.deletion_protection_enabled

  stream_enabled   = var.stream_enabled
  stream_view_type = var.stream_enabled ? var.stream_view_type : null

  dynamic "attribute" {
    for_each = var.attributes
    content {
      name = attribute.value.name
      type = attribute.value.type
    }
  }

  dynamic "global_secondary_index" {
    for_each = var.global_secondary_indexes
    content {
      name               = global_secondary_index.value.name
      hash_key           = global_secondary_index.value.hash_key
      range_key          = global_secondary_index.value.range_key
      projection_type    = global_secondary_index.value.projection_type
      non_key_attributes = global_secondary_index.value.non_key_attributes
      read_capacity      = local.is_provisioned ? global_secondary_index.value.read_capacity : null
      write_capacity     = local.is_provisioned ? global_secondary_index.value.write_capacity : null
    }
  }

  dynamic "local_secondary_index" {
    for_each = var.local_secondary_indexes
    content {
      name               = local_secondary_index.value.name
      range_key          = local_secondary_index.value.range_key
      projection_type    = local_secondary_index.value.projection_type
      non_key_attributes = local_secondary_index.value.non_key_attributes
    }
  }

  dynamic "ttl" {
    for_each = var.ttl_enabled ? [1] : []
    content {
      enabled        = true
      attribute_name = var.ttl_attribute_name
    }
  }

  point_in_time_recovery {
    enabled = var.point_in_time_recovery_enabled
  }

  dynamic "server_side_encryption" {
    for_each = var.server_side_encryption_enabled ? [1] : []
    content {
      enabled     = true
      kms_key_arn = local.kms_key_arn
    }
  }

  tags = merge(var.tags, { Name = var.name })
}
