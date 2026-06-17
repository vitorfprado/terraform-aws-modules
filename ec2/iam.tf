data "aws_iam_policy_document" "assume" {
  count = var.create_iam_instance_profile ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2" {
  count = var.create_iam_instance_profile ? 1 : 0

  name_prefix        = "${var.name}-"
  assume_role_policy = data.aws_iam_policy_document.assume[0].json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "ec2" {
  for_each = var.create_iam_instance_profile ? var.iam_role_policy_arns : {}

  role       = aws_iam_role.ec2[0].name
  policy_arn = each.value
}

resource "aws_iam_instance_profile" "ec2" {
  count = var.create_iam_instance_profile ? 1 : 0

  name_prefix = "${var.name}-"
  role        = aws_iam_role.ec2[0].name
  tags        = var.tags
}
