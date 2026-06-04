data "aws_partition" "current" {}

locals {
  default_ports = {
    postgres = 5432
    mysql    = 3306
    mariadb  = 3306
  }
  port = var.port != null ? var.port : lookup(local.default_ports, var.engine, 5432)

  create_kms_key_resource = var.storage_encrypted && var.create_kms_key && var.kms_key_arn == null
  kms_key_arn             = var.kms_key_arn != null ? var.kms_key_arn : (local.create_kms_key_resource ? aws_kms_key.rds[0].arn : null)

  security_group_ids = var.create_security_group ? concat([aws_security_group.rds[0].id], var.vpc_security_group_ids) : var.vpc_security_group_ids

  create_monitoring_role = var.monitoring_interval > 0 && var.create_monitoring_role
  monitoring_role_arn    = var.monitoring_interval > 0 ? (var.create_monitoring_role ? aws_iam_role.monitoring[0].arn : var.monitoring_role_arn) : null

  parameter_group_name = var.create_parameter_group ? aws_db_parameter_group.rds[0].name : var.parameter_group_name
}

resource "aws_db_subnet_group" "rds" {
  name_prefix = "${var.name}-"
  subnet_ids  = var.subnet_ids

  tags = merge(var.tags, { Name = var.name })
}

resource "aws_db_instance" "main" {
  identifier = var.name

  engine         = var.engine
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage > 0 ? var.max_allocated_storage : null
  storage_type          = var.storage_type
  storage_encrypted     = var.storage_encrypted
  kms_key_id            = var.storage_encrypted ? local.kms_key_arn : null

  db_name  = var.db_name
  username = var.username
  port     = local.port

  manage_master_user_password = var.manage_master_user_password ? true : null
  password                    = var.manage_master_user_password ? null : var.password

  multi_az               = var.multi_az
  publicly_accessible    = var.publicly_accessible
  db_subnet_group_name   = aws_db_subnet_group.rds.name
  vpc_security_group_ids = local.security_group_ids

  parameter_group_name = local.parameter_group_name

  backup_retention_period    = var.backup_retention_period
  backup_window              = var.backup_window
  maintenance_window         = var.maintenance_window
  auto_minor_version_upgrade = var.auto_minor_version_upgrade
  copy_tags_to_snapshot      = var.copy_tags_to_snapshot
  apply_immediately          = var.apply_immediately

  monitoring_interval = var.monitoring_interval
  monitoring_role_arn = local.monitoring_role_arn

  performance_insights_enabled    = var.performance_insights_enabled
  enabled_cloudwatch_logs_exports = var.enabled_cloudwatch_logs_exports

  deletion_protection       = var.deletion_protection
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : coalesce(var.final_snapshot_identifier, "${var.name}-final-snapshot")

  tags = merge(var.tags, { Name = var.name })
}
