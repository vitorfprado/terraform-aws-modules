resource "aws_security_group" "rds" {
  count = var.create_security_group ? 1 : 0

  name_prefix = "${var.name}-rds-"
  description = "Security group da instancia RDS ${var.name}"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, { Name = "${var.name}-rds" })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "cidr" {
  for_each = var.create_security_group ? toset(var.allowed_cidr_blocks) : []

  security_group_id = aws_security_group.rds[0].id
  description       = "Acesso ao banco a partir de ${each.value}"
  cidr_ipv4         = each.value
  from_port         = local.port
  to_port           = local.port
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "security_group" {
  for_each = var.create_security_group ? toset(var.allowed_security_group_ids) : []

  security_group_id            = aws_security_group.rds[0].id
  description                  = "Acesso ao banco a partir do security group ${each.value}"
  referenced_security_group_id = each.value
  from_port                    = local.port
  to_port                      = local.port
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "all" {
  count = var.create_security_group ? 1 : 0

  security_group_id = aws_security_group.rds[0].id
  description       = "Permite todo o trafego de saida"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
