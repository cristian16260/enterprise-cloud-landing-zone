###############################################################################
# MÓDULO: 00-bootstrap
# Propósito: Backend de Estado Remoto — S3 (versionado) + DynamoDB (bloqueo)
#
# IMPORTANTE: En la PRIMERA ejecución se usa estado LOCAL (sin backend).
#             Después de `terraform apply`, migra el estado al bucket creado:
#             terraform init -migrate-state
###############################################################################

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Backend remoto — descomenta DESPUÉS de la primera ejecución exitosa
  # y corre: terraform init -migrate-state
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

  # Práctica recomendada: tags globales inyectados por el provider
  # evitan que cualquier recurso quede sin etiquetar.
  default_tags {
    tags = var.global_tags
  }
}

###############################################################################
# LOCALES — Valores derivados centralizados para evitar repetición (DRY)
###############################################################################

locals {
  bucket_name = var.state_bucket_name
  table_name  = var.lock_table_name
}

###############################################################################
# S3 — Bucket de Estado Remoto
###############################################################################

# Recurso base del bucket
resource "aws_s3_bucket" "tfstate" {
  bucket = local.bucket_name

  # force_destroy = false garantiza que no se elimine accidentalmente
  # el bucket mientras contenga archivos de estado de Terraform.
  force_destroy = false

  # prevent_destroy como segunda capa de protección a nivel de plan
  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name = local.bucket_name
  }
}

# Versionado: permite recuperar cualquier versión anterior del estado
resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Encriptación en reposo obligatoria (AES-256 por defecto, sin costo adicional)
resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }

    # Garantiza que los objetos subidos sin especificar SSE también se encripten
    bucket_key_enabled = true
  }
}

# Bloqueo de acceso público: el estado de Terraform NUNCA debe ser público
resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

###############################################################################
# DynamoDB — Tabla de Bloqueo de Estado
###############################################################################

resource "aws_dynamodb_table" "tf_lock" {
  name = local.table_name

  # PAY_PER_REQUEST: ideal para bloqueos de Terraform que son esporádicos
  # y no justifican capacidad provisionada fija.
  billing_mode = "PAY_PER_REQUEST"

  # LockID es el atributo requerido por el backend de Terraform para S3
  hash_key = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  # PITR: permite restaurar la tabla a cualquier punto en los últimos 35 días
  point_in_time_recovery {
    enabled = true
  }

  # Protección contra eliminación accidental durante refactorizaciones
  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name = local.table_name
  }
}
