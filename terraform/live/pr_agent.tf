# PR-Agent (AI review) — one budget-capped OpenRouter key and one allow-list per
# repository that sets `pr_agent = { monthly_budget_usd = N }` in projects.tf.
# Nothing is created while no project sets it. See terraform/README.md.

variable "pr_agent_extra_users" {
  type        = list(string)
  description = "GitHub logins allowed to trigger PR-Agent on every PR-Agent repository, in addition to its admins and maintainers."
  default     = []

  validation {
    condition     = alltrue([for u in var.pr_agent_extra_users : can(regex("^[A-Za-z0-9]([A-Za-z0-9-]{0,37}[A-Za-z0-9])?$", u))])
    error_message = "pr_agent_extra_users entries must be valid GitHub logins."
  }
}

locals {
  # name => monthly budget, for the repositories whose pr_agent is set.
  pr_agent_budgets = {
    for p in local.all_projects : p.name => p.pr_agent.monthly_budget_usd
    if try(p.pr_agent, null) != null
  }
}

module "pr_agent" {
  source   = "../modules/pr_agent"
  for_each = local.pr_agent_budgets

  repository         = each.key
  monthly_budget_usd = each.value
  extra_users        = var.pr_agent_extra_users
  management_key_set = var.openrouter_management_key != ""
}
