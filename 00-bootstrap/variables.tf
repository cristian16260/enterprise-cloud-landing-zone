###############################################################################
# VARIABLES — 00-bootstrap
###############################################################################

variable "aws_region" {
  description = "Región de AWS donde se crearán los recursos de bootstrap."
  type        = string
  default     = "us-east-1"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.aws_region))
    error_message = "La región debe tener formato válido de AWS (ej: us-east-1, eu-west-2)."
  }
}

variable "state_bucket_name" {
  description = "Nombre único global del bucket S3 que almacenará el estado remoto de Terraform."
  type        = string
  default     = "enterprise-stack-2026-tfstate"

  validation {
    condition     = length(var.state_bucket_name) >= 3 && length(var.state_bucket_name) <= 63
    error_message = "El nombre del bucket debe tener entre 3 y 63 caracteres."
  }
}

variable "lock_table_name" {
  description = "Nombre de la tabla DynamoDB usada para el bloqueo de estado de Terraform."
  type        = string
  default     = "enterprise-stack-2026-tf-lock"
}

variable "global_tags" {
  description = "Tags globales aplicados a todos los recursos vía el bloque default_tags del provider."
  type        = map(string)
  default = {
    Project   = "Enterprise-Stack-2026"
    Owner     = "Cristian-Meza"
    ManagedBy = "Terraform"
    Module    = "00-bootstrap"
  }
}
