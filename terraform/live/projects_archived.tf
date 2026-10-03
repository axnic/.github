# Archived projects — read-only on GitHub.
#
# Move a module here from projects.tf when a repo is retired. It stays in
# local.all_projects (projects.tf) so the org profile still lists it, struck
# through. `archived = true` makes the repo read-only; `features = []` turns off
# issues, wiki, projects and discussions. Pull requests cannot be disabled
# separately (no provider attribute), but an archived repo accepts none.
#
# Keep the module block as-is when moving it: same name, so the state address
# does not change.

# ---------------------------------------------------------------------------
# pi-extension-settings — Pi extension to manage the settings of other pi extensions.
# ---------------------------------------------------------------------------
module "pi_extension_settings" {
  source    = "../modules/repository/pi_extension"
  providers = { github = github, toml = toml }

  name        = "pi-extension-settings"
  description = "A pi extension to manage settings of other extensions."

  archived          = true
  features          = []
  security_features = []

  npm_packages = ["@axnic/pi-extension-settings", "@axnic/pi-extension-settings-sdk"]

  required_code_scanning_tools = [{
    tool                      = "CodeQL"
    alerts_threshold          = "errors"
    security_alerts_threshold = "high_or_higher"
  }]

  ruleset_bypass_actors = local.ci_bypass_actors
}

# ---------------------------------------------------------------------------
# pi-aks-user-question — Pi extension letting LLMs ask structured questions through an interactive TUI form.
# ---------------------------------------------------------------------------
module "pi_aks_user_question" {
  source    = "../modules/repository/pi_extension"
  providers = { github = github, toml = toml }

  name        = "pi-aks-user-question"
  description = "A pi extension that lets LLMs ask structured questions to users via an interactive TUI form."

  archived          = true
  features          = []
  security_features = []

  npm_packages = ["@axnic/pi-aks-user-question"]

  required_code_scanning_tools = [{
    tool                      = "CodeQL"
    alerts_threshold          = "errors"
    security_alerts_threshold = "high_or_higher"
  }]

  ruleset_bypass_actors = local.ci_bypass_actors
}
