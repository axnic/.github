# ── Identity ──────────────────────────────────────────────────────────────────

variable "name" {
  type        = string
  description = "Repository name."
}

variable "description" {
  type        = string
  description = "Short, one-line repository description shown in the GitHub UI."
  default     = ""
}

variable "visibility" {
  type        = string
  description = "Repository visibility. One of: 'public', 'private'."
  default     = "public"

  validation {
    condition     = contains(["public", "private"], var.visibility)
    error_message = "visibility must be 'public' or 'private'."
  }
}

variable "topics" {
  type        = list(string)
  description = "GitHub topics to apply to the repository (used for discovery and filtering)."
  default     = []
}

# Archived repos are read-only on GitHub (no pushes, issues or PRs). Pair with
# `features = []` to also switch off issues, wiki, projects and discussions.
variable "archived" {
  type        = bool
  description = "Archive the repository (read-only)."
  default     = false
}

# ── Repository metadata ────────────────────────────────────────────────────────

# SPDX license template to apply. Must be a valid SPDX identifier
# (see https://spdx.org/licenses/). The provider creates the LICENSE file;
# leave null to skip. Note: changing this after creation may cause a diff on
# the tracked LICENSE file.
variable "license" {
  type        = string
  description = "Optional SPDX license identifier (e.g. MIT, GPL-3.0). Leave null to skip license file creation."
  default     = null

  validation {
    condition     = var.license == null || length(regexall("^[a-zA-Z0-9-.]+$", var.license)) > 0
    error_message = "license must be a valid SPDX identifier (e.g. MIT, GPL-3.0) or null."
  }
}

# ── Features ──────────────────────────────────────────────────────────────────

# Controls which GitHub repository features are enabled. Omit a value to
# disable the corresponding feature tab in the GitHub UI.
variable "features" {
  type        = list(string)
  description = "Enabled GitHub features. Valid values: \"issues\", \"wiki\", \"projects\", \"discussions\"."
  default     = ["issues"]

  validation {
    condition     = length([for f in var.features : f if contains(["issues", "wiki", "projects", "discussions"], f)]) == length(var.features)
    error_message = "features may only include 'issues', 'wiki', 'projects', 'discussions'."
  }
}

# List of named security capabilities to enable. Each value maps to a specific
# GitHub feature:
#
#   "code_security"                         — CodeQL code scanning. Free on public repos;
#                                             requires GHAS for private.
#   "secret_scanning"                       — Scan commits/PRs for leaked secrets. Free on
#                                             public repos; requires GHAS for private.
#   "secret_scanning_push_protection"       — Block pushes containing detected secrets.
#                                             Requires "secret_scanning". Free on public;
#                                             requires GHAS for private.
#   "secret_scanning_ai_detection"          — AI-assisted secret detection. Free on public;
#                                             requires GHAS for private.
#   "secret_scanning_non_provider_patterns" — Scan for custom org/repo secret patterns. Free
#                                             on public; requires GHAS for private.
#   "vulnerability_alerts"                  — Dependabot alerts (all repos). Renovate reads them to
#                                             open its security pull requests: keep them enabled.
#   "dependabot"                            — Dependabot security updates (PRs opened from the
#                                             alerts, no dependabot.yml needed). Off by default: pull
#                                             requests for updates and for alerts are Renovate's
#                                             (axnic/.github, default.json), which reads the alerts.
#                                             Enabling it gives an alert a Dependabot PR AND a
#                                             Renovate one. The alerts themselves ("vulnerability_alerts")
#                                             feed the Security tab and must stay on.
#
# The security_and_analysis block (code_security, secret_scanning and variants)
# is only emitted for public repos — these features are free there and GHAS is
# not required. For private GHAS repos, manage security_and_analysis outside this module.
#
# Default: all features enabled (safe for public repos).
variable "security_features" {
  type        = list(string)
  description = "Security features to enable. See variable comment for valid values and constraints."
  default     = ["vulnerability_alerts"]

  validation {
    condition = length([
      for f in var.security_features : f
      if contains(["vulnerability_alerts", "dependabot"], f)
    ]) == length(var.security_features)
    error_message = "security_features may only include 'vulnerability_alerts', 'dependabot'."
  }

  # push_protection requires secret_scanning to be active.
  validation {
    condition     = !contains(var.security_features, "secret_scanning_push_protection") || contains(var.security_features, "secret_scanning")
    error_message = "'secret_scanning_push_protection' requires 'secret_scanning' to also be enabled."
  }
}

# ── Branch protection ──────────────────────────────────────────────────────────

variable "required_status_checks" {
  type        = list(string)
  description = "CI status check contexts that must pass before a PR can merge (e.g. 'ci/test')."
  default     = []
}

# Code scanning tools whose results must meet the specified alert thresholds
# before a PR can merge. Each entry maps to one required_code_scanning_tool
# block in the main branch ruleset.
#
# Valid values for alerts_threshold:
#   "none", "errors", "errors_and_warnings", "all"
#
# Valid values for security_alerts_threshold:
#   "none", "critical", "high_or_higher", "medium_or_higher", "all"
#
# Example:
#   required_code_scanning_tools = [{
#     tool                      = "CodeQL"
#     alerts_threshold          = "errors"
#     security_alerts_threshold = "high_or_higher"
#   }]
variable "required_code_scanning_tools" {
  type = list(object({
    tool                      = string
    alerts_threshold          = string
    security_alerts_threshold = string
  }))
  description = "Code scanning tools that must pass alert thresholds before a PR can merge."
  default     = []

  validation {
    condition = alltrue([
      for t in var.required_code_scanning_tools :
      contains(["none", "errors", "errors_and_warnings", "all"], t.alerts_threshold)
    ])
    error_message = "alerts_threshold must be one of: none, errors, errors_and_warnings, all."
  }

  validation {
    condition = alltrue([
      for t in var.required_code_scanning_tools :
      contains(["none", "critical", "high_or_higher", "medium_or_higher", "all"], t.security_alerts_threshold)
    ])
    error_message = "security_alerts_threshold must be one of: none, critical, high_or_higher, medium_or_higher, all."
  }
}


# ── Issue labels ───────────────────────────────────────────────────────────────

# Extra labels merged with the module's default set (see locals in main.tf).
# Keys use GitLab-style scope::name convention. Caller values override defaults
# when keys clash.
#
# Example:
#   labels = {
#     "type::perf"     = { description = "Performance improvement", color = "0052cc" }
#     "priority::high" = { description = "Override default high-priority", color = "cc0000" }
#   }
variable "labels" {
  type = map(object({
    description = string
    color       = string
  }))
  description = "Extra issue labels (scope::name keys). Merged with defaults; caller values override on key collision."
  default     = {}
}

# ── Ruleset bypass actors ──────────────────────────────────────────────────────

# Actors allowed to bypass the main branch ruleset entirely.
# Intended for CI GitHub Apps (e.g. axnic-bot) that must push release commits
# directly to main without being blocked by required_signatures or status checks.
# Each entry maps to one bypass_actors block in github_repository_ruleset.
variable "ruleset_bypass_actors" {
  type = list(object({
    actor_id    = number
    actor_type  = string
    bypass_mode = string
  }))
  description = "Bypass actors for the main branch ruleset. Use only for trusted CI GitHub Apps — not for human contributors."
  default     = []

  validation {
    condition = alltrue([
      for a in var.ruleset_bypass_actors :
      contains(["RepositoryRole", "Team", "Integration", "OrganizationAdmin"], a.actor_type)
    ])
    error_message = "actor_type must be one of: RepositoryRole, Team, Integration, OrganizationAdmin."
  }

  validation {
    condition = alltrue([
      for a in var.ruleset_bypass_actors :
      contains(["always", "pull_request"], a.bypass_mode)
    ])
    error_message = "bypass_mode must be one of: always, pull_request."
  }
}

# ── Terraform GitHub App bypass ────────────────────────────────────────────────

# App ID of the GitHub App the Terraform provider authenticates with (live:
# var.github_app_id). Used to let Terraform commit the caller workflows (module
# workflows) straight to the protected default branch. "" = no bypass.
#
# REQUIREMENTS (not verifiable from Terraform, check them by hand):
#   - the app needs the repository permissions `Contents: write` AND
#     `Workflows: write` (GitHub refuses any write under .github/workflows/
#     without the `workflows` permission, whatever the ruleset says);
#   - validate this bypass on a test repository before relying on it. Fallback
#     if it does not work: commit the callers to a separate branch and merge a
#     pull request (the `branch` variable of modules/workflows).
variable "terraform_app_id" {
  type        = string
  description = "App ID of the Terraform provider's GitHub App, added as a ruleset bypass actor (Integration, always). \"\" = none."
  default     = ""
  nullable    = false
}

# Opt-out of the bypass above for one repository.
variable "terraform_app_bypass" {
  type        = bool
  description = "Add the Terraform GitHub App (terraform_app_id) as a bypass actor of the main ruleset."
  default     = true
  nullable    = false
}

# ── Central CI callers (modules/workflows) ─────────────────────────────────────

# Workflow groups of modules/workflows. null = the default of the repository
# type (base: ["core"]; the go and pulumi modules pass their own defaults).
# [] disables every caller of the repository (gradual adoption). Archived
# repositories never get callers.
variable "workflow_groups" {
  type        = list(string)
  description = "Workflow groups (core, issues, go, release, pulumi, security, oss, e2e, wiki). null = type default (base: core); [] = no callers."
  default     = null
}

variable "workflows" {
  type = list(object({
    workflow = string
  }))
  description = "Single catalog entries of modules/workflows enabled without their group (e.g. { workflow = \"pulumi.codegen\" })."
  default     = []
  nullable    = false
}

# Same shape as modules/workflows var.custom_workflows (validated there).
variable "custom_workflows" {
  type        = any
  description = "Repository-specific callers, see modules/workflows var.custom_workflows."
  default     = []
  nullable    = false
}

# modules/workflows var.settings (crons, path filters, central workflow inputs:
# scan_languages, go_os, go_paths,
# stale_days, review_model, e2e_commit_subject, e2e_readme_path, ...). Typed and
# validated there; the key check below catches typos, which an object
# conversion would silently drop.
variable "workflow_params" {
  type        = any
  description = "Per-workflow parameters, see modules/workflows var.settings."
  default     = {}
  nullable    = false

  validation {
    condition = alltrue([
      for k in keys(var.workflow_params) : contains([
        "go_paths", "go_os", "review_model", "review_fallback_model", "scan_cron", "scan_languages",
        "stale_cron", "stale_days", "stale_close_days",
        "audit_cron", "osv_cron", "scorecard_cron", "welcome_message", "pulumi_sdks", "e2e_sync_cron",
        "e2e_readme_path", "e2e_commit_subject", "wiki_docs_dir",
      ], k)
    ])
    error_message = "workflow_params keys must be attributes of modules/workflows var.settings (keep this list in sync)."
  }
}

# Commit message of the caller updates; must satisfy the repository's commitlint.
variable "workflow_commit_message" {
  type        = string
  description = "Commit message format for caller updates; %s = caller file name."
  default     = "ci(ci): Sync %s from axnic/.github"
  nullable    = false
}

# Publish job of the release caller ("go" | "pulumi"); null = derived from the groups.
variable "workflow_publish" {
  type        = string
  description = "Publish job of the release caller: \"go\" or \"pulumi\". null = derived from the groups."
  default     = null
}

# PR-Agent (AI review). Deliberately no budget default: null = no OpenRouter
# key and no AI Review caller. Here it only toggles the AI Review caller; the
# OpenRouter key and its budget are created in live.
variable "pr_agent" {
  type = object({
    monthly_budget_usd = number
  })
  description = "PR-Agent settings; null = no AI review. monthly_budget_usd caps the repository's OpenRouter key."
  default     = null

  validation {
    condition     = var.pr_agent == null ? true : coalesce(var.pr_agent.monthly_budget_usd, 0) > 0
    error_message = "pr_agent.monthly_budget_usd must be > 0."
  }
}
