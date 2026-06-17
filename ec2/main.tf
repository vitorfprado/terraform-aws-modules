data "aws_ami" "al2023" {
  count = var.ami_id == null ? 1 : 0

  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-${var.ami_architecture}"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

locals {
  ami_id = var.ami_id != null ? var.ami_id : data.aws_ami.al2023[0].id

  any_volume_encrypted    = var.root_volume_encrypted || anytrue([for v in var.ebs_volumes : v.encrypted])
  create_kms_key_resource = local.any_volume_encrypted && var.create_kms_key && var.kms_key_arn == null
  kms_key_arn             = var.kms_key_arn != null ? var.kms_key_arn : (local.create_kms_key_resource ? aws_kms_key.ec2[0].arn : null)

  security_group_ids   = var.create_security_group ? concat([aws_security_group.ec2[0].id], var.vpc_security_group_ids) : var.vpc_security_group_ids
  iam_instance_profile = var.create_iam_instance_profile ? aws_iam_instance_profile.ec2[0].name : var.iam_instance_profile
}

resource "aws_instance" "main" {
  ami           = local.ami_id
  instance_type = var.instance_type
  subnet_id     = var.subnet_id
  key_name      = var.key_name

  vpc_security_group_ids = local.security_group_ids
  iam_instance_profile   = local.iam_instance_profile

  associate_public_ip_address = var.associate_public_ip_address
  monitoring                  = var.monitoring

  user_data                   = var.user_data
  user_data_replace_on_change = var.user_data_replace_on_change

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = var.metadata_http_tokens
    http_put_response_hop_limit = var.metadata_http_put_response_hop_limit
  }

  root_block_device {
    volume_size = var.root_volume_size
    volume_type = var.root_volume_type
    encrypted   = var.root_volume_encrypted
    kms_key_id  = var.root_volume_encrypted ? local.kms_key_arn : null
  }

  tags = merge(var.tags, { Name = var.name })
}

resource "aws_ebs_volume" "additional" {
  for_each = { for v in var.ebs_volumes : v.device_name => v }

  availability_zone = aws_instance.main.availability_zone
  size              = each.value.size
  type              = each.value.type
  iops              = each.value.iops
  throughput        = each.value.throughput
  encrypted         = each.value.encrypted
  kms_key_id        = each.value.encrypted ? local.kms_key_arn : null

  tags = merge(var.tags, { Name = "${var.name}-${each.key}" })
}

resource "aws_volume_attachment" "additional" {
  for_each = { for v in var.ebs_volumes : v.device_name => v }

  device_name = each.key
  volume_id   = aws_ebs_volume.additional[each.key].id
  instance_id = aws_instance.main.id
}

resource "aws_eip" "main" {
  count = var.create_eip ? 1 : 0

  instance = aws_instance.main.id
  domain   = "vpc"

  tags = merge(var.tags, { Name = var.name })
}
