output "role_arn" {
  description = "ARN da IRSA role do controller. Vai na annotation eks.amazonaws.com/role-arn do service account."
  value       = module.role.role_arn
}

output "role_name" {
  description = "Nome da IAM role criada."
  value       = module.role.role_name
}

output "service_account_name" {
  description = "Nome do service account esperado pela trust policy. Use o mesmo valor em serviceAccount.name na instalação do chart."
  value       = var.service_account_name
}

output "namespace" {
  description = "Namespace esperado pela trust policy."
  value       = var.namespace
}

output "ssm_parameter_names" {
  description = "Nomes dos parâmetros publicados no Parameter Store, quando create_ssm_parameters é true."
  value       = { for k, v in aws_ssm_parameter.lb_controller : k => v.name }
}

output "helm_values" {
  description = "Valores mínimos do chart que dependem desta infraestrutura. Útil para gerar values.yaml ou alimentar um helm_release fora do módulo."
  value = {
    clusterName = var.cluster_name
    vpcId       = var.vpc_id
    region      = local.region
    serviceAccount = {
      create = true
      name   = var.service_account_name
      annotations = {
        "eks.amazonaws.com/role-arn" = module.role.role_arn
      }
    }
  }
}
