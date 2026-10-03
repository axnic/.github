# ── Target repository ─────────────────────────────────────────────────────────

variable "repository" {
  type        = string
  description = "Name of the repository (in the provider's owner) that receives the caller workflows."
}

variable "default_branch" {
  type        = string
  description = "Default branch: the mise-task guard reads it, and callers are committed there unless `branch` is set."
  default     = "main"

  # Rendered into YAML (`branches: ["..."]`).
  validation {
    condition     = can(regex("^[A-Za-z0-9._/-]+$", var.default_branch))
    error_message = "default_branch may only contain letters, digits, '.', '_', '/' and '-'."
  }
}

# Same values as the repository modules' `features`. Only used to refuse the
# `issues` group on a repository whose issues are switched off.
variable "features" {
  type        = list(string)
  description = "Enabled GitHub features of the repository (\"issues\", \"wiki\", \"projects\", \"discussions\")."
  default     = []
}

# Branch the callers are committed to. null = default_branch (direct commits).
# A separate branch prepares a pull-request mode; the mise-task guard always
# reads default_branch.
variable "branch" {
  type        = string
  description = "Branch the caller files are committed to; null = default_branch."
  default     = null
}

# ── Workflow selection ────────────────────────────────────────────────────────

# A group is a preset that expands to catalog entries (see local.catalog).
# `pulumi` includes `go`. `review` (group core) is only generated when
# pr_agent_enabled is true.
variable "workflow_groups" {
  type        = list(string)
  description = "Workflow groups to enable: core, issues, go, release, pulumi, security, oss, e2e, wiki."
  default     = []

  validation {
    condition = alltrue([
      for g in var.workflow_groups :
      contains(["core", "issues", "go", "release", "pulumi", "security", "oss", "e2e", "wiki"], g)
    ])
    error_message = "workflow_groups may only include core, issues, go, release, pulumi, security, oss, e2e, wiki."
  }

  validation {
    condition     = !contains(var.workflow_groups, "issues") || contains(var.features, "issues")
    error_message = "repo ${var.repository}: group `issues` requires the repository feature `issues` (add it to `features`)."
  }
}

# Single catalog entries enabled without their group, e.g.
#   workflows = [{ workflow = "pulumi.codegen" }]
variable "workflows" {
  type = list(object({
    workflow = string
  }))
  description = "Single catalog entries (central workflow stem, e.g. \"pulumi.codegen\") enabled without their group."
  default     = []

  validation {
    condition     = alltrue([for w in var.workflows : contains(keys(local.catalog), w.workflow)])
    error_message = "workflows[*].workflow must be a catalog entry: ${join(", ", sort(keys(local.catalog)))}."
  }

  # Explicitly asked for: refused rather than silently dropped.
  validation {
    condition     = !contains(var.workflows[*].workflow, "core.review") || var.pr_agent_enabled
    error_message = "repo ${var.repository}: workflow `core.review` requires pr_agent_enabled (an OpenRouter key)."
  }

  validation {
    condition     = !contains(var.workflows[*].workflow, "issues.stale") || contains(var.features, "issues")
    error_message = "repo ${var.repository}: workflow `issues.stale` requires the repository feature `issues` (add it to `features`)."
  }
}

# Repository-specific callers rendered from a template owned by the caller of
# this module. The file is named `<sorted triggers>.<action>.yaml` and gets the
# same trigger and mise-task checks as catalog entries. The template writes its
# own header and `name:`.
# The template receives: repository, default_branch, settings, publish, caller
# (its own file name), vars. `template` is read by templatefile() relative to the
# working directory, not to the calling module: pass "${path.module}/<file>"
# from the module that calls this one.
variable "custom_workflows" {
  type = list(object({
    action         = string
    triggers       = list(string)
    template       = string # "${path.module}/<file>.yaml.tftpl" of the calling module
    required_tasks = optional(list(string), [])
    vars           = optional(map(any), {})
  }))
  description = "Repository-specific caller workflows rendered from a local template."
  default     = []

  validation {
    condition     = alltrue([for c in var.custom_workflows : can(regex("^[a-z0-9][a-z0-9.-]*$", c.action))])
    error_message = "custom_workflows[*].action must be lower-case kebab-case (a-z, 0-9, '-', '.')."
  }

  validation {
    condition = alltrue([
      for c in var.custom_workflows :
      length(c.triggers) > 0 && length(distinct(c.triggers)) == length(c.triggers) &&
      alltrue([for t in c.triggers : can(regex("^[a-z_]+$", t))])
    ])
    error_message = "custom_workflows[*].triggers must be a non-empty list of distinct GitHub event names (a-z and '_')."
  }
}

# ── Release ───────────────────────────────────────────────────────────────────

# Which central workflow builds and publishes the release (second job of the
# release caller). null = "pulumi" when the pulumi group is enabled, else "go".
variable "publish" {
  type        = string
  description = "Publish job of the release caller: \"go\" (go.publish) or \"pulumi\" (pulumi.publish). null = derived from the groups."
  default     = null

  validation {
    condition     = var.publish == null || contains(["go", "pulumi"], coalesce(var.publish, "go"))
    error_message = "publish must be \"go\", \"pulumi\" or null."
  }
}

# ── PR-Agent ──────────────────────────────────────────────────────────────────

variable "pr_agent_enabled" {
  type        = bool
  description = "Generate the AI Review caller (core.review). True only when the repository has an OpenRouter key."
  default     = false
}

# ── Per-workflow parameters ───────────────────────────────────────────────────

# Inputs left null are not passed: the central workflow default applies.
# Crons belong to the caller (the central workflows only have workflow_call).
variable "settings" {
  type = object({
    # go.test
    go_paths = optional(list(string), ["**.go", "go.mod", "go.sum"]) # pull_request/push path filter
    go_os    = optional(list(string))                                # input `os`
    # core.review
    review_model          = optional(string) # input `model`
    review_fallback_model = optional(string) # input `fallback-model`
    # core.scan
    scan_cron      = optional(string, "0 6 * * *")
    scan_languages = optional(list(string)) # input `languages`
    # core.deps
    deps_subject_prefix = optional(string, "build(deps)") # input `subject-prefix`
    deps_merge_method   = optional(string, "merge")       # input `merge-method`: merge | squash
    # issues.stale
    stale_cron       = optional(string, "30 1 * * *")
    stale_days       = optional(number) # input `days-before-stale`
    stale_close_days = optional(number) # input `days-before-close`
    # security.audit
    audit_cron = optional(string, "0 6 * * *")
    # oss.scorecard / oss.welcome
    scorecard_cron  = optional(string, "0 5 * * 1")
    welcome_message = optional(string) # input `message`
    # pulumi.publish
    pulumi_sdks = optional(list(string)) # input `sdks`
    # e2e.sync
    e2e_sync_cron      = optional(string, "0 3 * * 1") # Monday 03:00 UTC
    e2e_readme_path    = optional(string)              # input `readme-path`
    e2e_commit_subject = optional(string)              # input `commit-subject` (central default: ci(ci): Sync E2E callers)
    # wiki.publish
    wiki_docs_dir = optional(string, "docs") # input `docs-dir` and push path filter
  })
  description = "Per-workflow parameters (crons, path filters, central workflow inputs). See the comments in variables.tf."
  default     = {}

  # Values rendered into the YAML of the callers.
  validation {
    condition = alltrue([
      for c in [var.settings.scan_cron, var.settings.stale_cron, var.settings.audit_cron, var.settings.scorecard_cron, var.settings.e2e_sync_cron] :
      can(regex("^[0-9A-Za-z*/,-]+( [0-9A-Za-z*/,-]+){4}$", c))
    ])
    error_message = "settings.*_cron must be 5-field cron expressions (digits, letters, '*', '/', ',', '-')."
  }

  validation {
    condition     = alltrue([for p in var.settings.go_paths : can(regex("^[^\"\\\\\n]+$", p))])
    error_message = "settings.go_paths entries must be non-empty and contain no double quote, backslash or newline."
  }

  validation {
    condition     = can(regex("^[A-Za-z0-9._-][A-Za-z0-9._/-]*$", var.settings.wiki_docs_dir))
    error_message = "settings.wiki_docs_dir may only contain letters, digits, '.', '_', '/' and '-' (no leading '/')."
  }

  validation {
    condition     = contains(["merge", "squash"], var.settings.deps_merge_method)
    error_message = "settings.deps_merge_method must be \"merge\" or \"squash\"."
  }
}

# ── Commits ───────────────────────────────────────────────────────────────────

# Each repository has its own commit convention (rtunk uses `type[scope]:`).
# `%s` is replaced by the caller file name.
variable "commit_message" {
  type        = string
  description = "Commit message format for caller updates; %s = caller file name."
  default     = "ci(ci): Sync %s from axnic/.github"

  validation {
    condition     = strcontains(var.commit_message, "%s")
    error_message = "commit_message must contain %s (the caller file name)."
  }
}

# Ordering hook for the caller commits only. Deliberately NOT a module-level
# depends_on: that would defer the guard's data sources to apply time.
variable "ready_after" {
  type        = any
  description = "Opaque value (e.g. a ruleset id); the callers are written only after it is known. The guard data sources do not depend on it."
  default     = null
}
