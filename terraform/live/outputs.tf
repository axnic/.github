output "all_projects" {
  description = "List of all managed project_info objects (useful for inspection)."
  value       = local.all_projects
}

output "public_readme" {
  description = "Rendered public org profile README content."
  value       = module.org_readme.rendered_public
}

output "private_readme" {
  description = "Rendered private org profile README content."
  value       = module.org_readme.rendered_private
}
