# PR-Agent for one repository: a budget-capped OpenRouter key stored as the
# OPENROUTER_API_KEY secret, and the PR_AGENT_ALLOWED_USERS allow-list (JSON list
# of logins) read by the central core.review workflow.

data "github_collaborators" "this" {
  owner      = var.owner
  repository = var.repository
}

locals {
  # Org owners show up as admins on org repos. Bots/apps (type != "User") are dropped.
  maintainers = [
    for c in data.github_collaborators.this.collaborator : c.login
    if contains(["admin", "maintain"], c.permission) && c.type == "User"
  ]
  allowed_users = sort(distinct(concat(local.maintainers, var.extra_users)))
}

resource "openrouter_api_key" "this" {
  name        = "pr-agent-${var.repository}"
  limit       = var.monthly_budget_usd
  limit_reset = "monthly"

  lifecycle {
    precondition {
      condition     = var.management_key_set
      error_message = "pr_agent is set for ${var.repository} but the workspace variable openrouter_management_key is empty."
    }
  }
}

resource "github_actions_secret" "openrouter_api_key" {
  repository      = var.repository
  secret_name     = "OPENROUTER_API_KEY"
  plaintext_value = openrouter_api_key.this.key
}

resource "github_actions_variable" "allowed_users" {
  repository    = var.repository
  variable_name = "PR_AGENT_ALLOWED_USERS"
  value         = jsonencode(local.allowed_users)

  lifecycle {
    precondition {
      condition     = length(local.allowed_users) > 0
      error_message = "PR_AGENT_ALLOWED_USERS would be empty for ${var.repository}: no admin/maintainer found. Set pr_agent_extra_users."
    }
  }
}

output "allowed_users" {
  description = "Logins written to PR_AGENT_ALLOWED_USERS."
  value       = local.allowed_users
}
