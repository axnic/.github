# Projects — all managed GitHub repositories.
#
# Usage:
#   1. Instantiate the appropriate repository/* module below.
#   2. Add the module's .project_info output to local.all_projects.
#   3. Open a PR → Terraform Cloud plans.
#   4. Merge to main → Terraform Cloud applies.
#
# local.all_projects feeds the org_readme module (organization.tf) and controls
# which repos appear in the public/private profile pages.

locals {
  # Bypass actor list for axnic-bot. Empty until var.ci_github_app_id is set
  # in Terraform Cloud (see docs/CI-GitHub-App.md). When populated, it is
  # passed to every module that needs the bot so the ruleset bypass is
  # registered automatically.
  #
  # When adding a new repo that needs the bot:
  #   1. Pass ruleset_bypass_actors = local.ci_bypass_actors to its module.
  #   2. Add its project_info.name to ci_bot_repos in ci_app.tf.
  ci_bypass_actors = var.ci_github_app_id != "" ? [{
    actor_id    = tonumber(var.ci_github_app_id)
    actor_type  = "Integration"
    bypass_mode = "always"
  }] : []

  all_projects = [
    module.pi_extension_settings.project_info,
    module.pi_aks_user_question.project_info,
    # go / pulumi repos set their own `type`; only pi_extension is rendered by
    # the profile templates. base-module repos have no `type`, so tag them "other".
    module.rtunk.project_info,
    module.pulumi_garage.project_info,
    module.pulumi_pocket_id.project_info,
    merge(module.medieval_claude.project_info, { type = "other" }),
  ]
}

# ---------------------------------------------------------------------------
# rtunk — One command for linters, formatters and security scanners, adopted via imports.tf.
# ---------------------------------------------------------------------------
module "rtunk" {
  source    = "../modules/repository/go"
  providers = { github = github, toml = toml }

  name        = "rtunk"
  description = "One command for your linters, formatters and security scanners. Open source, 100% local."
  features    = ["issues", "wiki", "projects"]
  # Module path in go.mod.
  go_modules = ["github.com/axnic/rtunk"]

  ci_workflow = "merge_group,pull_request,push.qa.yaml"

  # Central CI callers. The commit messages follow rtunk's `type[scope]:` convention
  # (symbol types, `=` = refactor/CI), so its commitlint passes on the direct push to main.
  # TODO(owner): set required_status_checks after the first PR run (see AGENTS.md).
  terraform_app_id        = var.github_app_id
  workflow_groups         = ["core", "go", "security", "release", "wiki", "oss"]
  workflow_commit_message = "=[ci]: Sync %s from axnic/.github"
  workflow_params = {
    deps_subject_prefix = "^[deps]"
    deps_merge_method   = "merge"
  }
  # 1 USD/month: decided by the owner
  pr_agent = { monthly_budget_usd = 1 }
}

# ---------------------------------------------------------------------------
# pulumi-garage — Pulumi provider for Garage (S3 object store), adopted via imports.tf.
# ---------------------------------------------------------------------------
module "pulumi_garage" {
  source    = "../modules/repository/pulumi"
  providers = { github = github, toml = toml }

  name         = "pulumi-garage"
  description  = "Pulumi provider for Garage (S3 object store)"
  extra_topics = ["go", "pulumi-provider", "garage"]
  features     = ["issues", "discussions"]

  ci_workflow    = "merge_group,pull_request,push.qa.yaml"
  npm_packages   = ["@axnic/pulumi-garage"]
  pypi_packages  = ["pulumi-garage"]
  nuget_packages = ["Axnic.Pulumi.Garage"]

  # Central CI callers: pulumi defaults + oss + e2e. The per-version E2E callers
  # are managed by e2e.sync (CI app secrets: ci_app.tf), not by Terraform.
  # `issues` is opt-in (the former stale job only ran in dry-run mode).
  # TODO(owner): set required_status_checks after the first PR run (see AGENTS.md).
  terraform_app_id = var.github_app_id
  workflow_groups  = ["core", "go", "security", "pulumi", "release", "oss", "e2e"]
  # 1 USD/month: decided by the owner
  pr_agent = { monthly_budget_usd = 1 }
}

# ---------------------------------------------------------------------------
# pulumi-pocket-id — Pulumi provider for Pocket ID, adopted via imports.tf.
# ---------------------------------------------------------------------------
module "pulumi_pocket_id" {
  source    = "../modules/repository/pulumi"
  providers = { github = github, toml = toml }

  name         = "pulumi-pocket-id"
  description  = "Pulumi provider for Pocket ID"
  extra_topics = ["go", "pulumi-provider", "pocket-id"]
  features     = ["issues", "discussions"]

  # !!! CENTRAL CI DISABLED ON PURPOSE (workflow_groups = []) !!!
  # The default branch `main` only holds the Pulumi boilerplate: the real
  # provider (and its mise tasks) lives in the unmerged branch stack
  # `sdk/generate-and-examples`. The mise-task guard reads `main`, so enabling
  # the groups now would fail the plan of the WHOLE organisation. Once that
  # stack is merged, replace the line below with the same groups as
  # pulumi-garage: ["core", "go", "security", "pulumi", "release", "oss", "e2e"],
  # and add this repo to ci_bot_repos in ci_app.tf (e2e.sync).
  # TODO(owner): set required_status_checks after the first PR run (see AGENTS.md).
  terraform_app_id = var.github_app_id
  workflow_groups  = []
  # TODO(owner): set pr_agent.monthly_budget_usd
}

# ---------------------------------------------------------------------------
# medieval-claude — Claude Code enchantments (JavaScript), adopted via imports.tf.
# ---------------------------------------------------------------------------
module "medieval_claude" {
  source    = "../modules/repository/base"
  providers = { github = github, toml = toml }

  name        = "medieval-claude"
  description = "Des enchantements pour Claude Code : la forme change, le fond jamais."
  features    = ["issues", "wiki", "projects"]

  # Central CI callers: core only.
  # TODO(owner): set required_status_checks after the first PR run (see AGENTS.md).
  terraform_app_id = var.github_app_id
  workflow_groups  = ["core"]
  # 1 USD/month: decided by the owner
  pr_agent = { monthly_budget_usd = 1 }
}
