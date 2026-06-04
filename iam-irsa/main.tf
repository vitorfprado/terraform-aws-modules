locals {
  # Defensivo: o output do módulo eks já vem sem https://, mas garante idempotência
  oidc_url = replace(var.oidc_provider_url, "https://", "")

  # "*" em qualquer posição libera todos os SAs do namespace (StringLike); caso
  # contrário, casa exatamente os SAs informados (StringEquals, semântica OR).
  wildcard   = contains(var.service_accounts, "*")
  sub_test   = local.wildcard ? "StringLike" : "StringEquals"
  sub_values = local.wildcard ? ["system:serviceaccount:${var.namespace}:*"] : [for sa in var.service_accounts : "system:serviceaccount:${var.namespace}:${sa}"]
}

# Trust policy: federa a role ao OIDC do cluster, restrita ao(s) service account(s).
data "aws_iam_policy_document" "assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_url}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = local.sub_test
      variable = "${local.oidc_url}:sub"
      values   = local.sub_values
    }
  }
}

resource "aws_iam_role" "irsa" {
  name                 = var.name
  assume_role_policy   = data.aws_iam_policy_document.assume.json
  max_session_duration = var.max_session_duration

  tags = merge(var.tags, { Name = var.name })
}

# Permissões inline (ARNs de recursos específicos — SQS, DynamoDB, etc.).
# for_each sobre as KEYS (estáticas) — o JSON pode ser known-after-apply.
resource "aws_iam_role_policy" "inline" {
  for_each = var.inline_policies

  name   = "${var.name}-${each.key}"
  role   = aws_iam_role.irsa.id
  policy = each.value
}

# Managed policies (AWS-managed ou customer-managed). Key estática; o ARN
# pode ser known-after-apply.
resource "aws_iam_role_policy_attachment" "managed" {
  for_each = var.policy_arns

  role       = aws_iam_role.irsa.name
  policy_arn = each.value
}
