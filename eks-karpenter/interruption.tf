# Tratamento de interrupção: o EventBridge publica os eventos do ciclo de vida
# das instâncias nesta fila, e o controller a consome para drenar o nó antes de
# a AWS recolhê-lo. Sem isso, uma interrupção de spot derruba os pods sem aviso.
resource "aws_sqs_queue" "interruption" {
  name                      = local.interruption_queue_name
  message_retention_seconds = var.interruption_queue_retention_seconds
  sqs_managed_sse_enabled   = true

  tags = merge(var.tags, { Name = local.interruption_queue_name })
}

data "aws_iam_policy_document" "interruption_queue" {
  statement {
    sid       = "EC2InterruptionPolicy"
    effect    = "Allow"
    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.interruption.arn]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com", "sqs.amazonaws.com"]
    }
  }
}

resource "aws_sqs_queue_policy" "interruption" {
  queue_url = aws_sqs_queue.interruption.url
  policy    = data.aws_iam_policy_document.interruption_queue.json
}

locals {
  interruption_events = {
    spot_interruption = {
      source      = "aws.ec2"
      detail_type = "EC2 Spot Instance Interruption Warning"
    }
    rebalance = {
      source      = "aws.ec2"
      detail_type = "EC2 Instance Rebalance Recommendation"
    }
    instance_state_change = {
      source      = "aws.ec2"
      detail_type = "EC2 Instance State-change Notification"
    }
    scheduled_change = {
      source      = "aws.health"
      detail_type = "AWS Health Event"
    }
  }
}

resource "aws_cloudwatch_event_rule" "interruption" {
  for_each = local.interruption_events

  name_prefix = "${var.cluster_name}-karpenter-"
  description = "Encaminha eventos de interrupção (${each.key}) para a fila do Karpenter do cluster ${var.cluster_name}."

  event_pattern = jsonencode({
    source      = [each.value.source]
    detail-type = [each.value.detail_type]
  })

  tags = var.tags
}

resource "aws_cloudwatch_event_target" "interruption" {
  for_each = local.interruption_events

  rule      = aws_cloudwatch_event_rule.interruption[each.key].name
  target_id = "KarpenterInterruptionQueue"
  arn       = aws_sqs_queue.interruption.arn
}
