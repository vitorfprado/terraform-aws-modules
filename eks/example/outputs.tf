output "vpc_id" {
  description = "ID da VPC criada para o cluster."
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "IDs das subnets privadas usadas pelo cluster."
  value       = module.vpc.private_subnet_ids
}

output "cluster_name" {
  description = "Nome do cluster EKS."
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Endpoint do servidor de API do Kubernetes."
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "Certificado da CA do cluster para o kubeconfig."
  value       = module.eks.cluster_certificate_authority_data
}

output "oidc_provider_arn" {
  description = "ARN do OIDC provider para uso em IRSA."
  value       = module.eks.oidc_provider_arn
}

output "kubeconfig_command" {
  description = "Comando para gerar o kubeconfig local apontando para o cluster."
  value       = "aws eks update-kubeconfig --region ${var.region} --name ${module.eks.cluster_name}"
}

output "oidc_provider_url" {
  description = "URL do issuer OIDC, para uso em IRSA e nos módulos de componentes do cluster."
  value       = module.eks.oidc_provider_url
}
