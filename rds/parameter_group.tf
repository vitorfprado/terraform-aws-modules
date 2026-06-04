resource "aws_db_parameter_group" "rds" {
  count = var.create_parameter_group ? 1 : 0

  name_prefix = "${var.name}-"
  family      = var.parameter_group_family

  dynamic "parameter" {
    for_each = var.parameters
    content {
      name         = parameter.value.name
      value        = parameter.value.value
      apply_method = parameter.value.apply_method
    }
  }

  tags = merge(var.tags, { Name = var.name })

  lifecycle {
    create_before_destroy = true
  }
}
