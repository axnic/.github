output "rendered_public" {
  description = "Rendered content of the public org profile README."
  value       = local.public_content
  sensitive   = false
}

output "rendered_private" {
  description = "Rendered content of the private org profile README."
  value       = local.private_content
  sensitive   = false
}
