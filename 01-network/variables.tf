###############################################################################
# VARIABLES — 01-network
###############################################################################

variable "aws_region" {
  description = "Región de AWS para los recursos de red."
  type        = string
  default     = "us-east-1"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.aws_region))
    error_message = "Formato de región inválido. Ejemplo: us-east-1, eu-west-2."
  }
}

variable "project_name" {
  description = "Prefijo para nombres de recursos. Solo minúsculas, números y guiones."
  type        = string
  default     = "enterprise-stack-2026"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Solo se permiten letras minúsculas, números y guiones."
  }
}

variable "vpc_cidr" {
  description = "Bloque CIDR de la VPC."
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrnetmask(var.vpc_cidr))
    error_message = "Debe ser un bloque CIDR válido (ej: 10.0.0.0/16)."
  }
}

variable "public_subnet_cidrs" {
  description = "CIDRs para las 2 subredes públicas — una por AZ."
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]

  validation {
    condition     = length(var.public_subnet_cidrs) == 2
    error_message = "Se requieren exactamente 2 CIDRs para despliegue Multi-AZ."
  }

  validation {
    condition     = alltrue([for cidr in var.public_subnet_cidrs : can(cidrnetmask(cidr))])
    error_message = "Todos los CIDRs deben ser bloques válidos."
  }
}

variable "private_subnet_cidrs" {
  description = "CIDRs para las 2 subredes privadas — una por AZ."
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]

  validation {
    condition     = length(var.private_subnet_cidrs) == 2
    error_message = "Se requieren exactamente 2 CIDRs para despliegue Multi-AZ."
  }

  validation {
    condition     = alltrue([for cidr in var.private_subnet_cidrs : can(cidrnetmask(cidr))])
    error_message = "Todos los CIDRs deben ser bloques válidos."
  }
}

variable "global_tags" {
  description = "Tags globales inyectados vía default_tags del provider."
  type        = map(string)
  default = {
    Project   = "Enterprise-Stack-2026"
    Owner     = "Cristian-Meza"
    ManagedBy = "Terraform"
    Module    = "01-network"
  }
}
