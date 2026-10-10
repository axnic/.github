module "base" {
  source    = "../base"
  providers = { github = github, toml = toml }

  name        = var.name
  description = var.description
  visibility  = var.visibility
  topics      = distinct(concat(["go", "golang"], var.extra_topics))
  features    = var.features
  license     = var.license

  required_status_checks       = var.required_status_checks
  required_code_scanning_tools = var.required_code_scanning_tools
  security_features            = var.security_features
  labels                       = var.labels

  ruleset_bypass_actors = var.ruleset_bypass_actors
  terraform_app_id      = var.terraform_app_id
  terraform_app_bypass  = var.terraform_app_bypass

  workflow_groups         = var.workflow_groups == null ? concat(["core", "go", "security", "release:go"], contains(var.features, "wiki") ? ["wiki"] : []) : var.workflow_groups
  workflows               = var.workflows
  custom_workflows        = var.custom_workflows
  workflow_params         = var.workflow_params
  workflow_commit_message = var.workflow_commit_message
  pr_agent                = var.pr_agent
}
