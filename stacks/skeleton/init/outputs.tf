output "logging_bucket_id" {
  value = module.init.logging_bucket_id
}
output "user_name" {
  value = module.init.user_name
}

output "access_id" {
  value       = module.init.access_id
  description = "The access id for the cicd user"
  sensitive   = true
}

output "secret" {
  value       = module.init.secret
  description = "The secret for the cicd user"
  sensitive   = true
}

