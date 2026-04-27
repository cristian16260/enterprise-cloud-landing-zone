###############################################################################
# OUTPUTS — 00-bootstrap
#
# Estos valores son consumidos por todos los módulos siguientes para configurar
# sus backends remotos (01-network, 02-compute, 03-observability, etc.)
# y para construir políticas IAM de roles de CI/CD.
###############################################################################

output "state_bucket_name" {
  description = "Nombre del bucket S3 para almacenamiento de estado remoto de Terraform."
  value       = aws_s3_bucket.tfstate.bucket
}

output "state_bucket_arn" {
  description = "ARN del bucket S3 de estado — usado en políticas IAM para roles de CI/CD."
  value       = aws_s3_bucket.tfstate.arn
}

output "lock_table_name" {
  description = "Nombre de la tabla DynamoDB de bloqueo."
  value       = aws_dynamodb_table.tf_lock.name
}

output "lock_table_arn" {
  description = "ARN de la tabla DynamoDB de bloqueo — usado en políticas IAM para roles de CI/CD."
  value       = aws_dynamodb_table.tf_lock.arn
}
