resource "aws_elasticache_parameter_group" "elasticache" {
  count = var.create_parameter_group ? 1 : 0

  name   = "${var.name}-params"
  family = var.parameter_group_family

  dynamic "parameter" {
    for_each = var.parameters
    content {
      name  = parameter.value.name
      value = parameter.value.value
    }
  }

  tags = merge(var.tags, { Name = var.name })

  lifecycle {
    create_before_destroy = true
  }
}
