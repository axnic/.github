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

# ── Repository metadata ────────────────────────────────────────────────────────

# SPDX license template. Leave null to skip license file creation.
# See https://spdx.org/licenses/ for valid identifiers.
variable "license" {
  type        = string
  description = "Optional SPDX license identifier (e.g. MIT, GPL-3.0). Leave null to skip."
  default     = null

  validation {
    condition     = var.license == null || length(regexall("^[a-zA-Z0-9-.]+$", var.license)) > 0
    error_message = "license must be a valid SPDX identifier (e.g. MIT, GPL-3.0) or null."
  }
}

# ── Topics ────────────────────────────────────────────────────────────────────

# Additional topics merged with the go defaults ("go", "golang").
variable "extra_topics" {
  type        = list(string)
  description = "Additional topics added alongside the built-in 'go' and 'golang' topics."
  default     = []
}

# ── Features ──────────────────────────────────────────────────────────────────

# Controls which GitHub repository features are enabled.
variable "features" {
  type        = list(string)
  description = "Enabled GitHub features. Valid values: \"issues\", \"wiki\", \"projects\", \"discussions\"."
  default     = ["issues"]

  validation {
    condition     = length([for f in var.features : f if contains(["issues", "wiki", "projects", "discussions"], f)]) == length(var.features)
    error_message = "features may only include 'issues', 'wiki', 'projects', 'discussions'."
  }
}

# See base module variable comment for full description of valid values.
# Default: all features enabled (safe for public repos).
variable "security_features" {
  type        = list(string)
  description = "Security features to enable. See variable comment for valid values and constraints."
  default     = ["vulnerability_alerts", "dependabot"]

  validation {
    condition = length([
      for f in var.security_features : f
      if contains(["vulnerability_alerts", "dependabot"], f)
    ]) == length(var.security_features)
    error_message = "security_features may only include 'vulnerability_alerts', 'dependabot'."
  }
}

# ── Branch protection ──────────────────────────────────────────────────────────

variable "required_status_checks" {
  type        = list(string)
  description = "CI status check contexts that must pass before a PR can merge (e.g. 'ci/test')."
  default     = []
}

# See base module variable comment for full description and valid threshold values.
variable "required_code_scanning_tools" {
  type = list(object({
    tool                      = string
    alerts_threshold          = string
    security_alerts_threshold = string
  }))
  description = "Code scanning tools that must pass alert thresholds before a PR can merge. Passed through to the base module."
  default     = []
}

# ── Go modules ────────────────────────────────────────────────────────────────

# Go module paths published by this repository (e.g. github.com/axnic/rtunk).
# Used to generate pkg.go.dev badges in the org profile README.
variable "go_modules" {
  type        = list(string)
  description = "Go module paths published by this repository. Used for badge generation."
  default     = []
}

# ── CI ────────────────────────────────────────────────────────────────────────

# File name of the main CI workflow under .github/workflows/ (e.g. "ci.yaml").
# Null skips the CI badge.
variable "ci_workflow" {
  type        = string
  description = "Main CI workflow file name, used for the CI status badge. Null skips the badge."
  default     = null
}

# ── Issue labels ───────────────────────────────────────────────────────────────

# Extra labels merged with the module's default set. Keys use GitLab-style
# scope::name convention. Caller values override defaults when keys clash.
variable "labels" {
  type = map(object({
    description = string
    color       = string
  }))
  description = "Extra issue labels (scope::name keys). Merged with defaults; caller values override on key collision."
  default     = {}
}

# ── Ruleset bypass actors ──────────────────────────────────────────────────────

variable "ruleset_bypass_actors" {
  type = list(object({
    actor_id    = number
    actor_type  = string
    bypass_mode = string
  }))
  description = "Bypass actors passed through to the base module's main branch ruleset."
  default     = []
}

# ── Terraform GitHub App bypass ────────────────────────────────────────────────

# See the base module: requires Contents + Workflows write on the app, and a
# validation on a test repository before relying on it.
variable "terraform_app_id" {
  type        = string
  description = "App ID of the Terraform provider's GitHub App, added as a ruleset bypass actor. \"\" = none."
  default     = ""
  nullable    = false
}

variable "terraform_app_bypass" {
  type        = bool
  description = "Add the Terraform GitHub App (terraform_app_id) as a bypass actor of the main ruleset."
  default     = true
  nullable    = false
}

# ── Central CI callers (modules/workflows) ─────────────────────────────────────

# null = the type default (core, go, security, release, plus wiki when the `wiki` feature is on); [] = no callers.
variable "workflow_groups" {
  type        = list(string)
  description = "Workflow groups of modules/workflows. null = type default; [] = no callers."
  default     = null
}

variable "workflows" {
  type = list(object({
    workflow = string
  }))
  description = "Single catalog entries of modules/workflows enabled without their group."
  default     = []
  nullable    = false
}

variable "custom_workflows" {
  type        = any
  description = "Repository-specific callers, see modules/workflows var.custom_workflows."
  default     = []
  nullable    = false
}

# See the base module (keys = modules/workflows var.settings).
variable "workflow_params" {
  type        = any
  description = "Per-workflow parameters, see modules/workflows var.settings."
  default     = {}
  nullable    = false
}

variable "workflow_commit_message" {
  type        = string
  description = "Commit message format for caller updates; %s = caller file name. Must satisfy the repository's commitlint."
  default     = "ci(ci): Sync %s from axnic/.github"
  nullable    = false
}

# No budget default: null = no OpenRouter key and no AI Review caller.
variable "pr_agent" {
  type = object({
    monthly_budget_usd = number
  })
  description = "PR-Agent settings; null = no AI review."
  default     = null

  validation {
    condition     = var.pr_agent == null ? true : coalesce(var.pr_agent.monthly_budget_usd, 0) > 0
    error_message = "pr_agent.monthly_budget_usd must be > 0."
  }
}
