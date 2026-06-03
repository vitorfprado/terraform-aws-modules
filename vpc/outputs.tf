output "vpc_id" {
  description = "ID da VPC."
  value       = aws_vpc.this.id
}

output "vpc_arn" {
  description = "ARN da VPC."
  value       = aws_vpc.this.arn
}

output "vpc_cidr_block" {
  description = "Bloco CIDR da VPC."
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "IDs das subnets públicas."
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs das subnets privadas."
  value       = aws_subnet.private[*].id
}

output "public_subnet_cidrs" {
  description = "CIDRs das subnets públicas."
  value       = aws_subnet.public[*].cidr_block
}

output "private_subnet_cidrs" {
  description = "CIDRs das subnets privadas."
  value       = aws_subnet.private[*].cidr_block
}

output "public_route_table_id" {
  description = "ID da route table das subnets públicas."
  value       = try(aws_route_table.public[0].id, null)
}

output "private_route_table_ids" {
  description = "IDs das route tables das subnets privadas."
  value       = aws_route_table.private[*].id
}

output "internet_gateway_id" {
  description = "ID do Internet Gateway."
  value       = try(aws_internet_gateway.this[0].id, null)
}

output "nat_gateway_ids" {
  description = "IDs dos NAT Gateways."
  value       = aws_nat_gateway.this[*].id
}

output "nat_public_ips" {
  description = "IPs públicos (EIPs) associados aos NAT Gateways."
  value       = aws_eip.nat[*].public_ip
}

output "azs" {
  description = "Zonas de disponibilidade utilizadas."
  value       = local.azs
}
