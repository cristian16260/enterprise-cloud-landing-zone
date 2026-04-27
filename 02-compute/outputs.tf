###############################################################################
# OUTPUTS — 02-compute
# Estos outputs validan que el sistema responde y sirven para futuras 
# integraciones de DNS (Route53) o validación en pipelines GitOps.
###############################################################################

output "alb_dns_name" {
  description = "DNS público del Application Load Balancer. Copia y pega esto en tu navegador."
  value       = aws_lb.web.dns_name
}

output "alb_arn" {
  description = "ARN del Load Balancer — Usado por futuros despliegues de métricas (CloudWatch)."
  value       = aws_lb.web.arn
}

output "autoscaling_group_name" {
  description = "Nombre del ASG."
  value       = aws_autoscaling_group.web.name
}

output "latest_ami_used" {
  description = "El ID de la Amazon Linux 2023 AMI inyectada dinámicamente en este despliegue."
  value       = data.aws_ami.al2023.id
}
