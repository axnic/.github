output "project_info" {
  description = "Standardised project metadata for consumption by higher-level modules (org_readme, etc)."
  value = {
    name        = github_repository.this.name
    url         = github_repository.this.html_url
    description = var.description
    visibility  = var.visibility
    archived    = var.archived
    topics      = var.topics
    pr_agent    = var.pr_agent

    # Flat list of Markdown badge strings; higher-level modules can concat/add more badges
    badges = [
      "[![Stars](https://img.shields.io/github/stars/${github_repository.this.full_name}?style=flat)](${github_repository.this.html_url})",
      "[![Latest Version](https://img.shields.io/github/v/release/${github_repository.this.full_name}?include_prereleases&display_name=release&style=flat&label=last%20version)](${github_repository.this.html_url}/packages)"
    ]
  }
}

output "workflow_files" {
  description = "Caller workflow files generated in .github/workflows/ by modules/workflows."
  value       = module.workflows.files
}
