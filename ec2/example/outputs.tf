output "instance_id" {
  description = "ID da instância criada."
  value       = module.ec2.instance_id
}

output "private_ip" {
  description = "IP privado da instância."
  value       = module.ec2.private_ip
}

output "ssm_session_command" {
  description = "Comando para abrir uma sessão SSM na instância."
  value       = "aws ssm start-session --target ${module.ec2.instance_id} --region ${var.region}"
}
