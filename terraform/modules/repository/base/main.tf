# Default labels applied to every managed repository.
# Scoped using GitLab-style "scope::name" convention for easy filtering.
# Colors use hex without the leading # (GitHub API requirement).
locals {
  default_labels = {
    # ── type ──────────────────────────────────────────────────────────────────
    "type::bug" = {
      description = "Something isn't working"
      color       = "d73a4a"
    }
    "type::feature" = {
      description = "New feature or request"
      color       = "a2eeef"
    }
    "type::docs" = {
      description = "Documentation only"
      color       = "0075ca"
    }
    "type::chore" = {
      description = "Maintenance — no feature or bug fix"
      color       = "e4e669"
    }
    "type::security" = {
      description = "Security issue or vulnerability"
      color       = "ee0701"
    }

    # ── priority ──────────────────────────────────────────────────────────────
    "priority::high" = {
      description = "Must be addressed urgently"
      color       = "e11d48"
    }
    "priority::medium" = {
      description = "Should be addressed soon"
      color       = "f97316"
    }
    "priority::low" = {
      description = "Nice to have, not urgent"
      color       = "84cc16"
    }

    # ── status ────────────────────────────────────────────────────────────────
    "status::in-progress" = {
      description = "Actively being worked on"
      color       = "7c3aed"
    }
    "status::blocked" = {
      description = "Blocked by an external dependency"
      color       = "6b7280"
    }
    "status::needs-review" = {
      description = "Ready for review"
      color       = "3b82f6"
    }
  }

  # Caller-supplied labels override defaults with the same key.
  merged_labels = merge(local.default_labels, var.labels)

  terraform_app_bypass_actors = var.terraform_app_bypass && var.terraform_app_id != "" ? [{
    actor_id    = tonumber(var.terraform_app_id)
    actor_type  = "Integration"
    bypass_mode = "always"
  }] : []
}

resource "github_repository" "this" {
  name        = var.name
  description = var.description
  visibility  = var.visibility
  topics      = var.topics
  archived    = var.archived

  # Always produce an initial commit so the default branch exists on creation.
  auto_init        = true
  license_template = var.license

  # ── Features ────────────────────────────────────────────────────────────────
  has_issues      = contains(var.features, "issues")
  has_wiki        = contains(var.features, "wiki")
  has_projects    = contains(var.features, "projects")
  has_discussions = contains(var.features, "discussions")

  # ── Merge strategy: merge commits only ──────────────────────────────────────
  # Merge commits preserve full history and keep the relationship between the
  # feature branch and the target branch explicit in the graph. Squash and
  # rebase are disabled to enforce a single, consistent strategy across all repos.
  allow_merge_commit = true
  allow_squash_merge = false
  allow_rebase_merge = false

  # Default merge commit title and message: use PR title and body so the commit
  # in main mirrors what was written in the PR description — no extra work needed.
  merge_commit_title   = "PR_TITLE"
  merge_commit_message = "PR_BODY"

  # Clean up merged branches automatically to prevent stale branch accumulation.
  delete_branch_on_merge = true

  # Suggest updating the PR branch when it falls behind the base branch.
  # Reduces "works on my branch" merge surprises.
  allow_update_branch = true

  # Allow PRs to be auto-merged once all required checks pass and approvals are
  # met. Speeds up merge for low-risk changes without sacrificing the gate.
  allow_auto_merge = true

  # Require contributors to sign off on web-based commits (DCO enforcement).
  # Ensures the same sign-off policy applies whether committing via CLI or UI.
  web_commit_signoff_required = true

  # ── Security analysis ───────────────────────────────────────────────────────
  # Features inside security_and_analysis are free for public repos.
  # Private repos require GHAS — the block is suppressed by default for them.
  # vulnerability_alerts is a top-level field and works for all repos.
  vulnerability_alerts = contains(var.security_features, "vulnerability_alerts")

  # Archive on destroy instead of deleting — preserves history and is reversible.
  archive_on_destroy = true

  # Guard against accidental deletion — remove this block explicitly before
  # running `terraform destroy` or removing a repo module from live/projects.tf.
  lifecycle {
    prevent_destroy = true
  }
}

resource "github_branch_default" "this" {
  repository = github_repository.this.name
  branch     = "main"
}

# Branch protection using GitHub Rulesets (REST API).
# Chosen over github_branch_protection_v3 because rulesets support bypass actors,
# allowing the CI (GitHub Actions) to push directly to main for automated release
# commits (e.g. version bumps in package.json) without weakening rules for humans.
resource "github_repository_ruleset" "main" {
  name        = "main"
  repository  = github_repository.this.name
  target      = "branch"
  enforcement = "active"

  conditions {
    ref_name {
      include = ["refs/heads/main"]
      exclude = []
    }
  }

  # Bypass actors: GitHub Apps installed in the axnic organisation can be
  # granted direct push access to main, bypassing all ruleset constraints.
  # Kept intentionally narrow — only dedicated CI apps, never human identities.
  # See docs/CI-GitHub-App.md for setup and workflow usage.
  # The Terraform provider's own app (terraform_app_id) is appended so it can
  # commit the caller workflows (module "workflows" below) to main. See the
  # requirements on var.terraform_app_id: Contents + Workflows write, and a
  # validation on a test repository first.
  dynamic "bypass_actors" {
    for_each = concat(var.ruleset_bypass_actors, local.terraform_app_bypass_actors)
    content {
      actor_id    = bypass_actors.value.actor_id
      actor_type  = bypass_actors.value.actor_type
      bypass_mode = bypass_actors.value.bypass_mode
    }
  }

  rules {
    # Require all commits on this branch to be cryptographically signed.
    # Prevents unsigned or forged commits from entering the protected branch.
    required_signatures = true

    # Require a pull request before any commit can land on main.
    # Bypass actors (e.g. CI bots) are still exempt via ruleset_bypass_actors.
    # Zero required approvals — the rule enforces the PR workflow; callers can
    # raise the bar via a wrapper module if needed.
    pull_request {
      required_approving_review_count   = 0
      dismiss_stale_reviews_on_push     = false
      require_code_owner_review         = false
      require_last_push_approval        = false
      required_review_thread_resolution = false
    }

    dynamic "required_status_checks" {
      for_each = length(var.required_status_checks) > 0 ? [1] : []
      content {
        # Strict mode: the branch must be up-to-date with base before merging.
        # Prevents "I tested on a stale branch" scenarios.
        strict_required_status_checks_policy = true

        dynamic "required_check" {
          for_each = var.required_status_checks
          content {
            # integration_id = 0 means any integration can report this check context.
            context        = required_check.value
            integration_id = 0
          }
        }
      }
    }

    dynamic "required_code_scanning" {
      for_each = length(var.required_code_scanning_tools) > 0 ? [1] : []
      content {
        dynamic "required_code_scanning_tool" {
          for_each = var.required_code_scanning_tools
          content {
            tool                      = required_code_scanning_tool.value.tool
            alerts_threshold          = required_code_scanning_tool.value.alerts_threshold
            security_alerts_threshold = required_code_scanning_tool.value.security_alerts_threshold
          }
        }
      }
    }
  }

  depends_on = [github_branch_default.this]
}

# Dependabot security updates: PRs that bump vulnerable dependencies, opened from the alerts
# (vulnerability_alerts above). Disabled by default: Renovate (axnic/.github, default.json) opens
# the update and security PRs, from the same alerts, which stay on for the Security tab.
resource "github_repository_dependabot_security_updates" "this" {
  repository = github_repository.this.name
  enabled    = contains(var.security_features, "dependabot")
}

# Issue labels — one resource per label, keyed by scoped name.
# Uses GitLab-style scope::name convention (e.g. type::bug, priority::high)
# so labels can be filtered and grouped by scope in the GitHub UI.
resource "github_issue_label" "this" {
  for_each = local.merged_labels

  repository  = github_repository.this.name
  name        = each.key
  description = each.value.description
  # GitHub expects the hex color without a leading #.
  color = each.value.color
}

# Central CI callers (thin workflows calling axnic/.github), generated per
# workflow group. Archived repositories are read-only: never any caller.
# The mise-task guard of the module reads the default branch at plan time (its data
# sources depend on nothing pending), so
# the repository's mise-task changes must be merged before the apply.
module "workflows" {
  source = "../../workflows"

  repository     = github_repository.this.name
  default_branch = github_branch_default.this.branch
  features       = var.features

  workflow_groups  = var.archived ? [] : coalesce(var.workflow_groups, ["core"])
  workflows        = var.archived ? [] : var.workflows
  custom_workflows = var.archived ? [] : var.custom_workflows
  settings         = var.workflow_params
  pr_agent_enabled = var.pr_agent != null
  commit_message   = var.workflow_commit_message

  # Commit only once the ruleset (and its Terraform app bypass) is in place.
  # Not a module-level depends_on: it would defer the guard to apply time.
  ready_after = github_repository_ruleset.main.id
}
