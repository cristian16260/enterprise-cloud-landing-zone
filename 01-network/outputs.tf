###############################################################################
# OUTPUTS — 01-network
#
# Estos outputs son el "contrato" que este módulo expone a los módulos futuros.
# Los módulos 02-compute, 03-observability (Grafana/NOC) y 04-gitops los
# consumen mediante:
#
#   data "terraform_remote_state" "network" {
#     backend = "s3"
#     config = {
#       bucket = "enterprise-stack-2026-tfstate"
#       key    = "network/terraform.tfstate"
#       region = "us-east-1"
#     }
#   }
#
# Acceso: data.terraform_remote_state.network.outputs.private_subnet_ids
###############################################################################

# --- VPC ---

output "vpc_id" {
  description = "ID de la VPC principal. Usado por todos los módulos de cómputo y observabilidad."
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "Bloque CIDR de la VPC. Usado en reglas de ingreso de Security Groups."
  value       = aws_vpc.main.cidr_block
}

# --- Subredes Públicas ---

output "public_subnet_ids" {
  description = "Lista de IDs de subredes públicas (AZ-1, AZ-2). Usadas por ALBs y NAT Gateway."
  value       = [for subnet in aws_subnet.public : subnet.id]
}

output "public_subnets" {
  description = "Mapa completo de subredes públicas (clave → objeto con id, cidr, az)."
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
  description = "Lista de IDs de subredes privadas (AZ-1, AZ-2). Usadas por ECS, EC2, agentes Grafana, RDS."
  value       = [for subnet in aws_subnet.private : subnet.id]
}

output "private_subnets" {
  description = "Mapa completo de subredes privadas (clave → objeto con id, cidr, az)."
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
  description = "ID del Internet Gateway adjunto a la VPC."
  value       = aws_internet_gateway.main.id
}

output "nat_gateway_id" {
  description = "ID del NAT Gateway. Usado para verificar conectividad saliente de cargas privadas."
  value       = aws_nat_gateway.main.id
}

output "nat_gateway_public_ip" {
  description = "IP pública del NAT Gateway. Agrega esta IP a listas blancas de servicios externos (Grafana Cloud, APIs SaaS)."
  value       = aws_eip.nat.public_ip
}
