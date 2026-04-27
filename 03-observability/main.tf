###############################################################################
# MÓDULO: 03-observability | NOC & Grafana
#
# Arquitectura: Instancia EC2 aislada en Subred Pública (para acceso web).
# Seguridad: Tráfico al puerto 3000 restringido a la IP de quien ejecuta.
# Permisos: Usa IAM Instance Profile para consultar CloudWatch sin credenciales.
###############################################################################

terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
    # Proveedor HTTP para autodescubrir tu IP pública por seguridad
    http = { source = "hashicorp/http", version = "~> 3.0" }
  }

  backend "s3" {
    bucket         = "enterprise-stack-2026-tfstate"
    key            = "observability/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "enterprise-stack-2026-tf-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
  default_tags { tags = var.global_tags }
}

###############################################################################
# DEPENDENCIAS REMOTAS & DATOS DINÁMICOS
###############################################################################

data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket = "enterprise-stack-2026-tfstate"
    key    = "network/terraform.tfstate"
    region = "us-east-1"
  }
}

data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

# Obtiene tu IP pública actual para inyectarla en el Security Group
data "http" "my_public_ip" {
  url = "https://ipv4.icanhazip.com"
}

###############################################################################
# IAM ROLE E INSTANCE PROFILE (Seguridad Sin Credenciales)
###############################################################################

resource "aws_iam_role" "grafana_role" {
  name = "${var.project_name}-grafana-role"

  # Permite que un servicio EC2 asuma este rol
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

# Adjuntamos la política de solo lectura a CloudWatch para que Grafana extraiga métricas
resource "aws_iam_role_policy_attachment" "cloudwatch_ro" {
  role       = aws_iam_role.grafana_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchReadOnlyAccess"
}

resource "aws_iam_instance_profile" "grafana_profile" {
  name = "${var.project_name}-grafana-profile"
  role = aws_iam_role.grafana_role.name
}

###############################################################################
# SECURITY GROUP NOC
###############################################################################

resource "aws_security_group" "noc" {
  name        = "${var.project_name}-noc-sg"
  description = "Reglas de firewall para el servidor NOC/Grafana"
  vpc_id      = data.terraform_remote_state.network.outputs.vpc_id

  # Grafana UI: Solo accesible desde tu IP
  ingress {
    description = "Grafana UI desde IP segura"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["${chomp(data.http.my_public_ip.response_body)}/32"]
  }

  # Tráfico HTTP/HTTPS para posible proxy o descargas
  ingress {
    description = "HTTP estandar"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS estandar"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Salida para descargar paquetes y hablar con APIs de AWS
  egress {
    description = "Salida total permitida"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

###############################################################################
# EC2 — Servidor NOC
###############################################################################

resource "aws_instance" "noc" {
  ami           = data.aws_ami.al2023.id
  instance_type = var.instance_type
  
  # Se despliega en la subred pública para tener salida a internet por IGW y acceso externo
  subnet_id = data.terraform_remote_state.network.outputs.public_subnet_ids[0]
  
  vpc_security_group_ids = [aws_security_group.noc.id]
  iam_instance_profile   = aws_iam_instance_profile.grafana_profile.name

  user_data = filebase64("${path.module}/user_data.sh")

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # IMDSv2 activo
    http_put_response_hop_limit = 1
  }

  tags = {
    Name = "monitoring-noc-01"
    Role = "Observability"
  }
}
