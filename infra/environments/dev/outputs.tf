output "demo_url" {
  value       = "http://${aws_lb.odoo.dns_name}"
  description = "Temporary HTTP-only demo URL. Do not use with real data."
}

output "database_secret_arn" {
  value     = aws_secretsmanager_secret.database.arn
  sensitive = true
}

output "destroy_command" {
  value = "terraform destroy -auto-approve"
}
