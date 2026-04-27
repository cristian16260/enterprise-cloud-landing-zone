###############################################################################
# MÓDULO: 01-network | Capa de Red Multi-AZ
#
# Topología: 1 VPC → 2 subredes públicas + 2 privadas (us-east-1a, us-east-1b)
# Salida a internet: IGW para subredes públicas, NAT GW para privadas.
#
# El NAT Gateway se despliega en una sola AZ para optimizar costos en
# entornos de desarrollo. En producción, desplegar uno por AZ y crear
# una tabla de rutas privada independiente por AZ para garantizar HA.
###############################################################################

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Backend remoto — provisionado por 00-bootstrap
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

  default_tags {
    tags = var.global_tags
  }
}

###############################################################################
# DATA SOURCE — Zonas de Disponibilidad
###############################################################################

data "aws_availability_zones" "available" {
  state = "available"
}

###############################################################################
# LOCALES — Mapas de subredes con claves estables para for_each
# Las claves ("public-az1") se usan como identificadores en el state file.
# Agregar o quitar una subred no reindexará las existentes.
###############################################################################

locals {
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
# VPC
###############################################################################

resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr

  # Requerido por Route 53 private zones, ECS Service Connect y SSM Session Manager
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

###############################################################################
# SUBREDES PÚBLICAS
###############################################################################

resource "aws_subnet" "public" {
  for_each = local.public_subnets

  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-${each.key}"
    Tier = "Public"
    AZ   = each.value.az
  }
}

###############################################################################
# SUBREDES PRIVADAS
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
###############################################################################

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

###############################################################################
# ELASTIC IP + NAT GATEWAY
# La EIP requiere que el IGW esté adjunto antes de asignarse (depends_on).
# El NAT GW se coloca en public-az1; las subredes privadas de ambas AZs
# enrutan tráfico saliente a través de él.
###############################################################################

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "${var.project_name}-nat-eip"
  }

  depends_on = [aws_internet_gateway.main]
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public["public-az1"].id

  tags = {
    Name = "${var.project_name}-nat-gw"
  }

  depends_on = [aws_internet_gateway.main]
}

###############################################################################
# TABLAS DE RUTAS
###############################################################################

# Pública — tráfico 0.0.0.0/0 → Internet Gateway
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

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# Privada — tráfico 0.0.0.0/0 → NAT Gateway
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

resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}
