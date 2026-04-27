###############################################################################
# VARIABLES — 03-observability
###############################################################################

variable "aws_region" {
  description = "Región de AWS."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Prefijo para los nombres de recursos."
  type        = string
  default     = "enterprise-stack-2026"
}

variable "instance_type" {
  description = "Tipo de instancia requerida para Grafana (consumo de RAM alto)."
  type        = string
  default     = "t3.medium"
}

variable "global_tags" {
  description = "Tags globales."
  type        = map(string)
  default = {
    Project   = "Enterprise-Stack-2026"
    Owner     = "Cristian-Meza"
    ManagedBy = "Terraform"
    Module    = "03-observability"
  }
}
