###############################################################################
# VARIABLES — 02-compute
###############################################################################

variable "aws_region" {
  description = "Región de despliegue."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Prefijo para los nombres de recursos de seguridad."
  type        = string
  default     = "enterprise-stack-2026"
}

variable "env" {
  description = "Entorno (dev, prod). Usado en nombres como alb-prod-web."
  type        = string
  default     = "prod"
}

variable "instance_type" {
  description = "Tipo de instancia EC2."
  type        = string
  default     = "t3.micro"
}

variable "asg_min" {
  description = "Capacidad mínima del Auto Scaling Group."
  type        = number
  default     = 2
}

variable "asg_max" {
  description = "Capacidad máxima del Auto Scaling Group."
  type        = number
  default     = 4
}

variable "asg_desired" {
  description = "Capacidad deseada inicial del Auto Scaling Group."
  type        = number
  default     = 2
}

variable "global_tags" {
  description = "Tags globales."
  type        = map(string)
  default = {
    Project   = "Enterprise-Stack-2026"
    Owner     = "Cristian-Meza"
    ManagedBy = "Terraform"
    Module    = "02-compute"
  }
}
