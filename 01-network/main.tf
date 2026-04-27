###############################################################################
# MÓDULO: 01-network
# Propósito: Capa de Red Central — VPC Multi-AZ, Subredes Públicas/Privadas,
#            Internet Gateway y NAT Gateway.
#
# ¿Por qué NAT Gateway? Los módulos futuros (agentes de Grafana, tareas ECS,
# funciones Lambda) en subredes PRIVADAS necesitan salida a internet para
# telemetría, actualizaciones y llamadas a APIs externas, sin exponerse
# públicamente.
#
# Práctica recomendada: Se usa `for_each` en lugar de `count` para subredes,
# lo que evita la re-indexación y destrucción accidental de recursos cuando
# se modifica la lista de CIDRs.
###############################################################################

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Backend remoto provisionado por 00-bootstrap
  backend "s3" {
    bucket         = "enterprise-stack-2026-tfstate"
    key            = "network/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "enterprise-stack-2026-tf-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region

  # Tags globales inyectados automáticamente en todos los recursos
  default_tags {
    tags = var.global_tags
  }
}

###############################################################################
# DATA SOURCE — Zonas de Disponibilidad
# Se resuelven dinámicamente para evitar hardcodear nombres de AZs.
###############################################################################

data "aws_availability_zones" "available" {
  state = "available"
}

###############################################################################
# LOCALES — Mapas de subredes para uso con `for_each`
#
# Usar for_each con un mapa (en lugar de count con lista) es la práctica
# recomendada de Terraform porque:
#   - El estado usa claves estables ("public-az1") en vez de índices frágiles (0, 1)
#   - Agregar o quitar una subred NO afecta a las demás en el plan de ejecución
###############################################################################

locals {
  # Mapa de subredes públicas: clave estable → configuración de subred
  public_subnets = {
    "public-az1" = {
      cidr = var.public_subnet_cidrs[0]
      az   = data.aws_availability_zones.available.names[0]
    }
    "public-az2" = {
      cidr = var.public_subnet_cidrs[1]
      az   = data.aws_availability_zones.available.names[1]
    }
  }

  # Mapa de subredes privadas: clave estable → configuración de subred
  private_subnets = {
    "private-az1" = {
      cidr = var.private_subnet_cidrs[0]
      az   = data.aws_availability_zones.available.names[0]
    }
    "private-az2" = {
      cidr = var.private_subnet_cidrs[1]
      az   = data.aws_availability_zones.available.names[1]
    }
  }
}

###############################################################################
# VPC PRINCIPAL
###############################################################################

resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr

  # Requerido para zonas hospedadas privadas de Route 53 y descubrimiento de
  # servicios ECS (Cloud Map)
  enable_dns_support = true

  # Requerido para SSM Session Manager y resolución de nombres de instancias EC2
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

###############################################################################
# SUBREDES PÚBLICAS
# Uso: Load Balancers de aplicación, NAT Gateway, hosts bastión (si aplica)
###############################################################################

resource "aws_subnet" "public" {
  # for_each con mapa garantiza claves estables en el estado de Terraform
  for_each = local.public_subnets

  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az

  # Los ALBs y bastiones necesitan IPs públicas automáticas al lanzarse
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-${each.key}"
    Tier = "Public"
    AZ   = each.value.az
  }
}

###############################################################################
# SUBREDES PRIVADAS
# Uso: Cargas de trabajo ECS/EC2, agentes Grafana, RDS, Lambda
###############################################################################

resource "aws_subnet" "private" {
  for_each = local.private_subnets

  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az

  tags = {
    Name = "${var.project_name}-${each.key}"
    Tier = "Private"
    AZ   = each.value.az
  }
}

###############################################################################
# INTERNET GATEWAY
# Proporciona a las subredes públicas una ruta de salida hacia internet.
###############################################################################

resource "aws_internet_gateway" "main" {
  # La asociación con la VPC se hace aquí, no como recurso separado (práctica recomendada)
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

###############################################################################
# ELASTIC IP — Requerida para el NAT Gateway
###############################################################################

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "${var.project_name}-nat-eip"
  }

  # La EIP debe crearse después de que el IGW esté adjunto a la VPC
  # para evitar errores de dependencia en el plan
  depends_on = [aws_internet_gateway.main]
}

###############################################################################
# NAT GATEWAY — Desplegado en subred pública AZ-1
#
# Nota de arquitectura: Para alta disponibilidad completa en producción,
# despliega un NAT Gateway por AZ y crea una tabla de rutas privada por AZ.
# En este entorno de desarrollo/staging se usa uno solo para optimizar costos.
###############################################################################

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id

  # Ubicado en la primera subred pública usando la clave del mapa
  subnet_id = aws_subnet.public["public-az1"].id

  tags = {
    Name = "${var.project_name}-nat-gw"
  }

  # Garantiza que el IGW exista antes de crear el NAT Gateway
  depends_on = [aws_internet_gateway.main]
}

###############################################################################
# TABLA DE RUTAS — Pública
# Dirige todo el tráfico de salida (0.0.0.0/0) hacia el Internet Gateway
###############################################################################

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

# Asociación: vincula cada subred pública a la tabla de rutas pública
resource "aws_route_table_association" "public" {
  # for_each sobre el mapa de subnets para mantener coherencia con los recursos anteriores
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

###############################################################################
# TABLA DE RUTAS — Privada
# El tráfico de salida pasa por el NAT Gateway, no directamente a internet.
# Esto mantiene las cargas de trabajo privadas sin IPs públicas expuestas.
###############################################################################

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-private-rt"
  }
}

# Asociación: vincula cada subred privada a la tabla de rutas privada
resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}
