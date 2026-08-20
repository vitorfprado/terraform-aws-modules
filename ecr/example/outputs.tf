output "registry_url" {
  description = "URL base do registry — alvo do docker login."
  value       = module.ecr.registry_url
}

output "repository_urls" {
  description = "URL de cada repositório — destino do docker push."
  value       = module.ecr.repository_urls
}

output "ssm_parameter_names" {
  description = "Parâmetros publicados no Parameter Store."
  value       = module.ecr.ssm_parameter_names
}
