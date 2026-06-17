resource "aws_security_group" "ec2" {
  count = var.create_security_group ? 1 : 0

  name_prefix = "${var.name}-"
  description = "Security group da instância ${var.name}"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, { Name = var.name })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "ec2" {
  for_each = var.create_security_group ? { for idx, rule in var.ingress_rules : tostring(idx) => rule } : {}

  security_group_id            = aws_security_group.ec2[0].id
  description                  = each.value.description
  from_port                    = each.value.from_port
  to_port                      = each.value.to_port
  ip_protocol                  = each.value.ip_protocol
  cidr_ipv4                    = each.value.cidr_ipv4
  referenced_security_group_id = each.value.referenced_security_group_id
}

resource "aws_vpc_security_group_egress_rule" "all" {
  count = var.create_security_group ? 1 : 0

  security_group_id = aws_security_group.ec2[0].id
  description       = "Permite todo o tráfego de saída"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
