output "instance_id" {
  description = "ID da instância EC2."
  value       = aws_instance.main.id
}

output "instance_arn" {
  description = "ARN da instância EC2."
  value       = aws_instance.main.arn
}

output "availability_zone" {
  description = "Zona de disponibilidade em que a instância foi lançada."
  value       = aws_instance.main.availability_zone
}

output "private_ip" {
  description = "IP privado da instância."
  value       = aws_instance.main.private_ip
}

output "public_ip" {
  description = "IP público da instância (EIP quando criado, senão o IP público efêmero, se houver)."
  value       = var.create_eip ? aws_eip.main[0].public_ip : aws_instance.main.public_ip
}

output "private_dns" {
  description = "Nome DNS privado da instância."
  value       = aws_instance.main.private_dns
}

output "security_group_id" {
  description = "ID do security group criado pelo módulo, quando habilitado."
  value       = try(aws_security_group.ec2[0].id, null)
}

output "iam_role_arn" {
  description = "ARN da IAM role da instância, quando criada pelo módulo."
  value       = try(aws_iam_role.ec2[0].arn, null)
}

output "iam_role_name" {
  description = "Nome da IAM role da instância, quando criada pelo módulo."
  value       = try(aws_iam_role.ec2[0].name, null)
}

output "instance_profile_name" {
  description = "Nome do instance profile em uso pela instância."
  value       = local.iam_instance_profile
}

output "kms_key_arn" {
  description = "ARN da KMS key usada na criptografia dos volumes, quando uma key dedicada é criada pelo módulo."
  value       = try(aws_kms_key.ec2[0].arn, null)
}
