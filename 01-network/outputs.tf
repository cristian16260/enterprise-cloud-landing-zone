###############################################################################
# OUTPUTS — 01-network
# Contrato público de este módulo. Consumido por módulos posteriores vía:
#
#   data "terraform_remote_state" "network" {
#     backend = "s3"
#     config  = { bucket = "enterprise-stack-2026-tfstate", key = "network/terraform.tfstate", region = "us-east-1" }
#   }
###############################################################################

# --- VPC ---

output "vpc_id" {
  description = "ID de la VPC principal."
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "CIDR de la VPC — usado en reglas de Security Groups para tráfico interno."
  value       = aws_vpc.main.cidr_block
}

# --- Subredes Públicas ---

output "public_subnet_ids" {
  description = "IDs de subredes públicas como lista — compatible con parámetros de ALB y ASG."
  value       = [for subnet in aws_subnet.public : subnet.id]
}

output "public_subnets" {
  description = "Mapa de subredes públicas con id, cidr y az por clave."
  value = {
    for key, subnet in aws_subnet.public : key => {
      id   = subnet.id
      cidr = subnet.cidr_block
      az   = subnet.availability_zone
    }
  }
}

# --- Subredes Privadas ---

output "private_subnet_ids" {
  description = "IDs de subredes privadas como lista — compatible con parámetros de ECS, RDS y Lambda."
  value       = [for subnet in aws_subnet.private : subnet.id]
}

output "private_subnets" {
  description = "Mapa de subredes privadas con id, cidr y az por clave."
  value = {
    for key, subnet in aws_subnet.private : key => {
      id   = subnet.id
      cidr = subnet.cidr_block
      az   = subnet.availability_zone
    }
  }
}

# --- Gateways ---

output "internet_gateway_id" {
  description = "ID del Internet Gateway."
  value       = aws_internet_gateway.main.id
}

output "nat_gateway_id" {
  description = "ID del NAT Gateway."
  value       = aws_nat_gateway.main.id
}

output "nat_gateway_public_ip" {
  description = "IP pública del NAT — agregar a whitelists de APIs externas y Grafana Cloud."
  value       = aws_eip.nat.public_ip
}
