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

variable "archived" {
  type        = bool
  description = "Archive the repository (read-only). Pair with features = [] to switch off issues, wiki, projects and discussions."
  default     = false
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

# Additional topics merged with the pi_extension defaults ("pi-agent", "extension").
variable "extra_topics" {
  type        = list(string)
  description = "Additional topics added alongside the built-in 'pi-agent' and 'extension' topics."
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
  default     = ["vulnerability_alerts"]

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

# ── npm packages ──────────────────────────────────────────────────────────────

# List of npm packages published by this repository. Used to generate npm
# badge URLs in the org profile README.
variable "npm_packages" {
  type        = list(string)
  description = "npm packages published by this repository (e.g. @org/package-name). Used for badge generation."
  default     = []
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
