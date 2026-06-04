output "role_arn" {
  description = "ARN da IRSA role. Use na annotation eks.amazonaws.com/role-arn do ServiceAccount."
  value       = aws_iam_role.irsa.arn
}

output "role_name" {
  description = "Nome da IRSA role."
  value       = aws_iam_role.irsa.name
}

output "role_unique_id" {
  description = "ID único (estável) da role."
  value       = aws_iam_role.irsa.unique_id
}

output "ssm_parameter_name" {
  description = "Nome do parâmetro SSM com o ARN da role, quando publicado."
  value       = try(aws_ssm_parameter.role_arn[0].name, null)
}

output "ssm_parameter_arn" {
  description = "ARN do parâmetro SSM, quando publicado."
  value       = try(aws_ssm_parameter.role_arn[0].arn, null)
}
