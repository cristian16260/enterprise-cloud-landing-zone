###############################################################################
# OUTPUTS — 00-bootstrap
# Consumidos por los backends de los módulos 01-network, 02-compute, etc.
# y por políticas IAM de roles de CI/CD.
###############################################################################

output "state_bucket_name" {
  description = "Nombre del bucket S3 de estado remoto."
  value       = aws_s3_bucket.tfstate.bucket
}

output "state_bucket_arn" {
  description = "ARN del bucket — referenciado en políticas IAM de pipelines CI/CD."
  value       = aws_s3_bucket.tfstate.arn
}

output "lock_table_name" {
  description = "Nombre de la tabla DynamoDB de bloqueo."
  value       = aws_dynamodb_table.tf_lock.name
}

output "lock_table_arn" {
  description = "ARN de la tabla de bloqueo — referenciado en políticas IAM de pipelines CI/CD."
  value       = aws_dynamodb_table.tf_lock.arn
}
