data "aws_iam_policy_document" "aws_lbc_assume" {
  count = var.enable_aws_load_balancer_controller ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider_url}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider_url}:sub"
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }
  }
}

resource "aws_iam_role" "aws_lbc" {
  count = var.enable_aws_load_balancer_controller ? 1 : 0

  name_prefix        = "${var.cluster_name}-aws-lbc-"
  assume_role_policy = data.aws_iam_policy_document.aws_lbc_assume[0].json
  tags               = var.tags
}

resource "aws_iam_policy" "aws_lbc" {
  count = var.enable_aws_load_balancer_controller ? 1 : 0

  name_prefix = "${var.cluster_name}-aws-lbc-"
  description = "Permissões do AWS Load Balancer Controller para o cluster ${var.cluster_name}"
  policy      = file("${path.module}/policies/aws_lbc_iam_policy.json")
  tags        = var.tags
}

resource "aws_iam_role_policy_attachment" "aws_lbc" {
  count = var.enable_aws_load_balancer_controller ? 1 : 0

  role       = aws_iam_role.aws_lbc[0].name
  policy_arn = aws_iam_policy.aws_lbc[0].arn
}

resource "helm_release" "aws_lbc" {
  count = var.enable_aws_load_balancer_controller ? 1 : 0

  name       = "aws-load-balancer-controller"
  namespace  = "kube-system"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = var.aws_load_balancer_controller_chart_version

  set = concat(
    [
      { name = "clusterName", value = var.cluster_name },
      { name = "vpcId", value = var.vpc_id },
      { name = "serviceAccount.create", value = "true" },
      { name = "serviceAccount.name", value = "aws-load-balancer-controller" },
      { name = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn", value = aws_iam_role.aws_lbc[0].arn },
    ],
    local.region != null ? [{ name = "region", value = local.region }] : [],
  )

  values = var.aws_load_balancer_controller_helm_values

  depends_on = [aws_iam_role_policy_attachment.aws_lbc]
}
