###############################################################################
# OUTPUTS — 03-observability
###############################################################################

output "grafana_access_url" {
  description = "URL directa para acceder al dashboard de Grafana."
  value       = "http://${aws_instance.noc.public_ip}:3000"
}

output "noc_instance_id" {
  description = "ID de la instancia EC2 del NOC."
  value       = aws_instance.noc.id
}

output "grafana_role_arn" {
  description = "ARN del rol de IAM, util si necesitamos agregar mas permisos en el futuro (ej: X-Ray, Prometheus)."
  value       = aws_iam_role.grafana_role.arn
}
