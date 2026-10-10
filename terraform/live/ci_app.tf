# CI release GitHub App — repository-level secrets
#
# axnic-bot credentials are scoped to the repos that actually need the bot
# (those that have ruleset_bypass_actors = local.ci_bypass_actors in projects.tf).
# No org-wide secret is created — principle of least privilege.
#
# When adding a new repo that needs axnic-bot (ruleset bypass, or the "e2e" workflow group):
#   1. In projects.tf: pass ruleset_bypass_actors = local.ci_bypass_actors (bypass only).
#   2. Here: add module.<name>.project_info.name to ci_bot_repos.
#
# All three variables default to "" so this file is a no-op until
# var.ci_github_app_id is set in Terraform Cloud (see docs/CI-GitHub-App.md).

locals {
  ci_bot_repos = var.ci_github_app_id != "" ? toset([
    # e2e group: the central e2e.sync workflow reads CI_APP_ID / CI_APP_PRIVATE_KEY to push the
    # per-version caller files under .github/workflows/ (the app needs `workflows: write`).
    module.pulumi_garage.project_info.name,
    module.pulumi_pocket_id.project_info.name,
    module.argocd_extension_application_map.project_info.name,
    # Archived repos stay listed on purpose: dropping them would destroy their secrets, and the
    # GitHub API refuses writes on archived repos (403), which could abort the org apply. Remove
    # them with a `terraform state rm` migration once the owner confirms.
    module.pi_extension_settings.project_info.name,
    module.pi_aks_user_question.project_info.name,
  ]) : toset([])
}

resource "github_actions_secret" "ci_app_id" {
  for_each        = local.ci_bot_repos
  repository      = each.value
  secret_name     = "CI_APP_ID"
  plaintext_value = var.ci_github_app_id
}

resource "github_actions_secret" "ci_app_installation_id" {
  for_each        = local.ci_bot_repos
  repository      = each.value
  secret_name     = "CI_APP_INSTALLATION_ID"
  plaintext_value = var.ci_github_app_installation_id
}

resource "github_actions_secret" "ci_app_private_key" {
  for_each        = local.ci_bot_repos
  repository      = each.value
  secret_name     = "CI_APP_PRIVATE_KEY"
  plaintext_value = var.ci_github_app_pem_file
}
