locals {
  base_name  = endswith(var.name, ".fifo") ? trimsuffix(var.name, ".fifo") : var.name
  queue_name = var.fifo_queue ? "${local.base_name}.fifo" : local.base_name
  dlq_name   = var.fifo_queue ? "${local.base_name}-dlq.fifo" : "${local.base_name}-dlq"

  use_kms                 = var.create_kms_key || var.kms_master_key_id != null
  create_kms_key_resource = var.create_kms_key && var.kms_master_key_id == null
  kms_key_id              = var.kms_master_key_id != null ? var.kms_master_key_id : (local.create_kms_key_resource ? aws_kms_key.sqs[0].arn : null)
}

resource "aws_sqs_queue" "dlq" {
  count = var.create_dlq ? 1 : 0

  name = local.dlq_name

  fifo_queue                  = var.fifo_queue
  content_based_deduplication = var.fifo_queue ? var.content_based_deduplication : null

  message_retention_seconds = var.dlq_message_retention_seconds

  sqs_managed_sse_enabled           = local.use_kms ? null : true
  kms_master_key_id                 = local.use_kms ? local.kms_key_id : null
  kms_data_key_reuse_period_seconds = local.use_kms ? var.kms_data_key_reuse_period_seconds : null

  tags = merge(var.tags, { Name = local.dlq_name })
}

resource "aws_sqs_queue" "main" {
  name = local.queue_name

  fifo_queue                  = var.fifo_queue
  content_based_deduplication = var.fifo_queue ? var.content_based_deduplication : null
  deduplication_scope         = var.fifo_queue ? var.deduplication_scope : null
  fifo_throughput_limit       = var.fifo_queue ? var.fifo_throughput_limit : null

  visibility_timeout_seconds = var.visibility_timeout_seconds
  message_retention_seconds  = var.message_retention_seconds
  max_message_size           = var.max_message_size
  delay_seconds              = var.delay_seconds
  receive_wait_time_seconds  = var.receive_wait_time_seconds

  sqs_managed_sse_enabled           = local.use_kms ? null : true
  kms_master_key_id                 = local.use_kms ? local.kms_key_id : null
  kms_data_key_reuse_period_seconds = local.use_kms ? var.kms_data_key_reuse_period_seconds : null

  redrive_policy = var.create_dlq ? jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq[0].arn
    maxReceiveCount     = var.max_receive_count
  }) : null

  tags = merge(var.tags, { Name = local.queue_name })
}

resource "aws_sqs_queue_policy" "main" {
  count = var.policy != null ? 1 : 0

  queue_url = aws_sqs_queue.main.id
  policy    = var.policy
}
