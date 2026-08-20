data "aws_partition" "current" {}
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  partition  = data.aws_partition.current.partition
  account_id = data.aws_caller_identity.current.account_id

  # .name e não .region: o atributo region só existe no provider AWS 6+, e este
  # módulo declara >= 5.40. O name está deprecado no 6 mas continua funcionando,
  # então é o único que atende a faixa inteira. Revisar quando a biblioteca subir
  # o piso para 6.
  region = coalesce(var.region, data.aws_region.current.name)

  controller_role_name    = coalesce(var.controller_role_name, "${var.cluster_name}-karpenter-controller")
  node_role_name          = coalesce(var.node_role_name, "${var.cluster_name}-karpenter-node")
  interruption_queue_name = coalesce(var.interruption_queue_name, "${var.cluster_name}-karpenter")
}
