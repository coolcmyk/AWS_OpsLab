output "application_url" { value = "http://${module.compute.alb_dns_name}" }
output "ecr_repository_url" { value = module.compute.ecr_repository_url }
output "evidence_bucket" { value = module.storage.evidence_bucket_name }
output "event_bus_name" { value = module.events.event_bus_name }
output "database_secret_arn" { value = module.database.app_secret_arn, sensitive = true }
