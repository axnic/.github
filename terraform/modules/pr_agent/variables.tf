variable "repository" {
  type        = string
  description = "Repository name (without owner) that receives the PR-Agent secret and allow-list."
}

variable "owner" {
  type        = string
  description = "GitHub organisation owning the repository."
  default     = "axnic"
}

variable "monthly_budget_usd" {
  type        = number
  description = "Monthly spending limit (USD) of the repository's OpenRouter key."

  validation {
    condition     = var.monthly_budget_usd > 0
    error_message = "monthly_budget_usd must be > 0."
  }
}

variable "extra_users" {
  type        = list(string)
  description = "GitHub logins allowed to trigger PR-Agent in addition to the repository's admins and maintainers."
  default     = []

  validation {
    condition     = alltrue([for u in var.extra_users : can(regex("^[A-Za-z0-9]([A-Za-z0-9-]{0,37}[A-Za-z0-9])?$", u))])
    error_message = "extra_users entries must be valid GitHub logins (alphanumerics and single hyphens, max 39 chars)."
  }
}

variable "management_key_set" {
  type        = bool
  description = "Whether the OpenRouter management key is non-empty. Guards the key creation with a clear error."
}
