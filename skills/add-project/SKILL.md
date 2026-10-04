---
name: add-project
description: >
  Use this skill when asked to add a new repository, register a new project,
  onboard a repo, or wire a GitHub repo into the organisation's Terraform
  infrastructure. Also use it when the user references projects.tf,
  all_projects, or ci_bot_repos — even without explicitly mentioning Terraform.
compatibility: Requires mise (tf:fmt:fix, tf:validate commands)
allowed-tools: Bash(git:*) Bash(mise run*)
---

# Add a New Project

## ⚠️ Gotchas

- **Never edit `README.md` by hand.** Both org profile READMEs (`README.md`
  in `.github` and in `.github-private`) are owned by the
  `org_readme` Terraform module and overwritten on every apply. Edit the
  templates in `modules/org_readme/templates/` instead.
- Projects are declared in `terraform/live/projects.tf`, **not** `main.tf`.
  `main.tf` only manages the org-infra repos themselves.
- Module labels must use `snake_case` — HCL identifiers cannot contain hyphens
  (`pi-aks-user-question` → `pi_aks_user_question`).

## Steps

### 1. Choose the module type

| Module                               | Use for             |
| ------------------------------------ | ------------------- |
| `../modules/repository/pi_extension` | pi-agent extensions |
| `../modules/repository/base`         | Any other repo type |

### 2. Add the module block in `projects.tf`

Append to `terraform/live/projects.tf`:

```hcl
# ---------------------------------------------------------------------------
# <repo-name>
# ---------------------------------------------------------------------------
module "<repo_name>" {
  source    = "../modules/repository/pi_extension"
  providers = { github = github, toml = toml }

  name        = "<repo-name>"
  description = "<One-line description.>"

  # Central CI callers: null = type default, [] = none (see AGENTS.md "Central CI wiring").
  # Merge the repo's mise-task PRs BEFORE the apply (plan-time guard).
  terraform_app_id = var.github_app_id # app needs Contents + Workflows write
  workflow_groups  = ["core"]
  # TODO(owner): set pr_agent.monthly_budget_usd (never set a budget by default)

  features          = ["issues"]
  security_features = ["vulnerability_alerts"] # alerts only: Renovate opens the PRs

  npm_packages = ["@axnic/<package-name>"] # omit if no npm packages

  required_code_scanning_tools = [{
    tool                      = "CodeQL"
    alerts_threshold          = "errors"
    security_alerts_threshold = "high_or_higher"
  }]

  ruleset_bypass_actors = local.ci_bypass_actors # omit if bot not needed
}
```

### 3. Add to `local.all_projects` in `projects.tf`

```hcl
all_projects = [
  module.pi_extension_settings.project_info,
  module.<repo_name>.project_info, # ← new line
]
```

### 4. (If bot needed) Update `ci_app.tf`

Add to `ci_bot_repos` in `terraform/live/ci_app.tf`:

```hcl
ci_bot_repos = var.ci_github_app_id != "" ? toset([
  module.pi_extension_settings.project_info.name,
  module.<repo_name>.project_info.name, # ← new line
]) : toset([])
```

> Needed for a CI release workflow with axnic-bot, or when the repo uses the `e2e` workflow group.
> Must also pass `ruleset_bypass_actors = local.ci_bypass_actors` in the module block.

### 5. Format, validate, and commit

```sh
mise run tf:fmt:fix   # fix HCL formatting
mise run tf:validate  # init (no backend) + validate
```

Use the `commit` skill to write the commit message, then open a PR.
Terraform Cloud runs a speculative plan on PR open and applies on merge to `main`.
