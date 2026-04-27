###############################################################################
# MÓDULO: 02-compute | Capa de Cómputo Inmutable y Balanceo
#
# Arquitectura: 
#   - ALB (Public Subnets) → Traffic → ASG (Private Subnets).
#   - Nodos EC2 100% aislados (sin IP pública, solo accesibles por ALB).
###############################################################################

terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }

  backend "s3" {
    bucket         = "enterprise-stack-2026-tfstate"
    key            = "compute/terraform.tfstate"
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
# DEPENDENCIAS CROSS-MÓDULO (Remote State)
# Extrae vpc_id y subnet_ids del módulo 01-network sin acoplamiento duro.
###############################################################################

data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket = "enterprise-stack-2026-tfstate"
    key    = "network/terraform.tfstate"
    region = "var.aws_region" # Fallback, se usa el string directo
    region = "us-east-1"
  }
}

###############################################################################
# DATA SOURCES — Última AMI de Amazon Linux 2023
###############################################################################

data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

###############################################################################
# SECURITY GROUPS (Principio de Menor Privilegio)
###############################################################################

# SG del ALB: Permite HTTP desde internet
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "Permite trafico web entrante al ALB"
  vpc_id      = data.terraform_remote_state.network.outputs.vpc_id

  ingress {
    description = "HTTP desde Internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Salida total permitida"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# SG de EC2: Solo permite tráfico que provenga EXCLUSIVAMENTE del ALB
resource "aws_security_group" "ec2" {
  name        = "${var.project_name}-ec2-sg"
  description = "Permite trafico unicamente desde el ALB"
  vpc_id      = data.terraform_remote_state.network.outputs.vpc_id

  ingress {
    description     = "HTTP exclusivo desde ALB SG"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "Salida total para descargar paquetes via NAT GW"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

###############################################################################
# APPLICATION LOAD BALANCER (ALB)
###############################################################################

resource "aws_lb" "web" {
  name               = "alb-${var.env}-web" # Ej: alb-prod-web
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  
  # ALB requiere subredes públicas para recibir tráfico de internet
  subnets = data.terraform_remote_state.network.outputs.public_subnet_ids

  enable_deletion_protection = false # En prod esto debería ser 'true'
}

resource "aws_lb_target_group" "web" {
  name     = "tg-${var.env}-web"
  port     = 80
  protocol = "HTTP"
  vpc_id   = data.terraform_remote_state.network.outputs.vpc_id

  health_check {
    path                = "/"
    healthy_threshold   = 2
    unhealthy_threshold = 5
    timeout             = 5
    interval            = 10 # Checkeos rápidos para ambientes inmutables
    matcher             = "200"
  }
}

resource "aws_lb_listener" "web" {
  load_balancer_arn = aws_lb.web.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}

###############################################################################
# LAUNCH TEMPLATE & AUTO SCALING GROUP (ASG)
###############################################################################

resource "aws_launch_template" "web" {
  name_prefix   = "lt-${var.env}-web-"
  image_id      = data.aws_ami.al2023.id
  instance_type = var.instance_type

  vpc_security_group_ids = [aws_security_group.ec2.id]

  # Se pasa el script externo y se renderiza en tiempo de despliegue
  user_data = filebase64("${path.module}/user_data.sh")

  # IMDSv2 requerido (Estándar de Seguridad)
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "web" {
  name                = "asg-${var.env}-web"
  desired_capacity    = var.asg_desired
  min_size            = var.asg_min
  max_size            = var.asg_max
  
  # Los nodos inmutables viven seguros en las subredes privadas
  vpc_zone_identifier = data.terraform_remote_state.network.outputs.private_subnet_ids

  target_group_arns = [aws_lb_target_group.web.arn]
  health_check_type = "ELB" # El ASG reemplazará la instancia si Nginx falla, no solo si la VM cae

  launch_template {
    id      = aws_launch_template.web.id
    version = "$Latest"
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }

  tag {
    key                 = "Name"
    value               = "EC2-${var.env}-Web-Node"
    propagate_at_launch = true
  }
}
