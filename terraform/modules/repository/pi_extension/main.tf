module "base" {
  source    = "../base"
  providers = { github = github, toml = toml }

  name        = var.name
  description = var.description
  visibility  = var.visibility
  archived    = var.archived
  topics      = distinct(concat(["pi-agent", "extension"], var.extra_topics))
  features    = var.features
  license     = var.license

  required_status_checks       = var.required_status_checks
  required_code_scanning_tools = var.required_code_scanning_tools
  security_features            = var.security_features
  labels                       = var.labels

  ruleset_bypass_actors = var.ruleset_bypass_actors
}
