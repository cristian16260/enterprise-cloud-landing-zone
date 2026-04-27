###############################################################################
# VARIABLES — 00-bootstrap
###############################################################################

variable "aws_region" {
  description = "Región de AWS para los recursos de bootstrap."
  type        = string
  default     = "us-east-1"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.aws_region))
    error_message = "Formato de región inválido. Ejemplo: us-east-1, eu-west-2."
  }
}

variable "state_bucket_name" {
  description = "Nombre del bucket S3 para estado remoto. Debe ser único globalmente en AWS."
  type        = string
  default     = "enterprise-stack-2026-tfstate"

  validation {
    condition     = length(var.state_bucket_name) >= 3 && length(var.state_bucket_name) <= 63
    error_message = "El nombre del bucket debe tener entre 3 y 63 caracteres (restricción de S3)."
  }
}

variable "lock_table_name" {
  description = "Nombre de la tabla DynamoDB para bloqueo de estado."
  type        = string
  default     = "enterprise-stack-2026-tf-lock"
}

variable "global_tags" {
  description = "Tags globales inyectados vía default_tags del provider."
  type        = map(string)
  default = {
    Project   = "Enterprise-Stack-2026"
    Owner     = "Cristian-Meza"
    ManagedBy = "Terraform"
    Module    = "00-bootstrap"
  }
}
