###############################################################################
# MÓDULO: 00-bootstrap | Backend de Estado Remoto
# Primera ejecución: estado LOCAL. Después de apply, ejecutar:
#   terraform init -migrate-state
###############################################################################

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Descomenta después de la primera ejecución y corre: terraform init -migrate-state
  # backend "s3" {
  #   bucket         = "enterprise-stack-2026-tfstate"
  #   key            = "bootstrap/terraform.tfstate"
  #   region         = "us-east-1"
  #   dynamodb_table = "enterprise-stack-2026-tf-lock"
  #   encrypt        = true
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = var.global_tags
  }
}

###############################################################################
# LOCALES
###############################################################################

locals {
  bucket_name = var.state_bucket_name
  table_name  = var.lock_table_name
}

###############################################################################
# S3 — Bucket de Estado
###############################################################################

resource "aws_s3_bucket" "tfstate" {
  bucket        = local.bucket_name
  # Cambiado a true para permitir el borrado de Terraform (Nota: igual debes vaciar archivos a mano antes)
  force_destroy = true

  # ⚠️ ADVERTENCIA FINOPS: 
  # En producción, prevent_destroy DEBE ser true para evitar la pérdida accidental del estado.
  # Se ha comentado para permitir la destrucción completa del entorno y ahorrar costos.
  # lifecycle {
  #   prevent_destroy = true
  # }

  tags = {
    Name = local.bucket_name
  }
}

resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    # Reduce el número de llamadas a la API de KMS por objeto almacenado
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

###############################################################################
# DynamoDB — Tabla de Bloqueo
# El atributo LockID es requerido por la implementación del backend S3 de Terraform.
###############################################################################

resource "aws_dynamodb_table" "tf_lock" {
  name         = local.table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  # ⚠️ ADVERTENCIA FINOPS: 
  # Comentado para permitir destrucción total.
  # En un entorno real, descomenta esto para proteger tu tabla de bloqueos de Terraform.
  # lifecycle {
  #   prevent_destroy = true
  # }

  tags = {
    Name = local.table_name
  }
}
