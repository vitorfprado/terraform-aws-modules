output "cluster_name" {
  description = "Nome do cluster EKS."
  value       = aws_eks_cluster.this.name
}

output "cluster_arn" {
  description = "ARN do cluster EKS."
  value       = aws_eks_cluster.this.arn
}

output "cluster_endpoint" {
  description = "Endpoint do servidor de API do Kubernetes."
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_version" {
  description = "Versão do Kubernetes em execução no control plane."
  value       = aws_eks_cluster.this.version
}

output "cluster_certificate_authority_data" {
  description = "Certificado da CA do cluster, em base64, usado para autenticação no kubeconfig."
  value       = aws_eks_cluster.this.certificate_authority[0].data
}

output "cluster_security_group_id" {
  description = "ID do security group gerenciado pelo EKS para comunicação entre control plane e nodes."
  value       = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}

output "cluster_iam_role_arn" {
  description = "ARN da IAM role do control plane."
  value       = local.cluster_role_arn
}

output "node_iam_role_arn" {
  description = "ARN da IAM role compartilhada pelos node groups."
  value       = local.node_role_arn
}

output "node_iam_role_name" {
  description = "Nome da IAM role compartilhada pelos node groups."
  value       = try(aws_iam_role.node[0].name, null)
}

output "oidc_provider_arn" {
  description = "ARN do OIDC provider do cluster, usado em políticas de confiança para IRSA."
  value       = try(aws_iam_openid_connect_provider.this[0].arn, null)
}

output "oidc_provider_url" {
  description = "URL do issuer OIDC do cluster (sem o prefixo https://)."
  value       = try(replace(aws_eks_cluster.this.identity[0].oidc[0].issuer, "https://", ""), null)
}

output "kms_key_arn" {
  description = "ARN da KMS key usada para criptografar os secrets do cluster."
  value       = local.encryption_key_arn
}

output "cloudwatch_log_group_name" {
  description = "Nome do log group do CloudWatch com os logs do control plane."
  value       = aws_cloudwatch_log_group.this.name
}

output "node_groups" {
  description = "Atributos dos managed node groups criados, indexados pela chave informada em node_groups."
  value = {
    for k, ng in aws_eks_node_group.this : k => {
      arn           = ng.arn
      status        = ng.status
      capacity_type = ng.capacity_type
      asg_names     = ng.resources[0].autoscaling_groups[*].name
    }
  }
}

output "cluster_addons" {
  description = "Atributos dos EKS add-ons gerenciados, indexados pelo nome do add-on."
  value = {
    for k, addon in aws_eks_addon.this : k => {
      arn     = addon.arn
      version = addon.addon_version
    }
  }
}

output "ebs_csi_driver_iam_role_arn" {
  description = "ARN da IAM role (IRSA) do add-on aws-ebs-csi-driver, quando habilitado."
  value       = try(aws_iam_role.ebs_csi[0].arn, null)
}
