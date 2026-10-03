variable "github_app_id" {
  type        = string
  description = "GitHub App ID for provider authentication. Set as a workspace variable in Terraform Cloud."
}

variable "github_app_installation_id" {
  type        = string
  description = "GitHub App installation ID for the axnic organisation. Set as a workspace variable in Terraform Cloud."
}

variable "github_app_pem_file" {
  type        = string
  description = "GitHub App private key (PEM contents). Set as a sensitive workspace variable in Terraform Cloud — never commit."
  sensitive   = true
}

# ── CI release GitHub App (axnic-bot) ─────────────────────────────────────────
# Leave all three empty until the app is created (see docs/CI-GitHub-App.md).
# When set, Terraform registers the bypass actor in each repo's ruleset and
# creates the three CI secrets on every repository that needs the bot.

variable "ci_github_app_id" {
  type        = string
  description = "App ID of the axnic-bot GitHub App."
  default     = ""
}

variable "ci_github_app_installation_id" {
  type        = string
  description = "Installation ID of axnic-bot in the axnic organisation."
  default     = ""
}

variable "ci_github_app_pem_file" {
  type        = string
  sensitive   = true
  description = "Private key (PEM) for axnic-bot. Set as a sensitive workspace variable in Terraform Cloud — never commit."
  default     = ""
}

# ── OpenRouter ────────────────────────────────────────────────────────────────

variable "openrouter_management_key" {
  type        = string
  sensitive   = true
  description = "OpenRouter management key for the openrouter provider. Set as a sensitive workspace variable in Terraform Cloud — never commit."
}
