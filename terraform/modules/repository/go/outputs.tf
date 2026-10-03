locals {
  repo = trimprefix(module.base.project_info.url, "https://github.com/")
}

output "project_info" {
  description = "Standardised project metadata consumed by the org_readme module."

  value = merge(
    module.base.project_info,
    {
      type = "go"

      badges = concat(
        module.base.project_info.badges,
        ["[![Go version](https://img.shields.io/github/go-mod/go-version/${local.repo}?style=flat)](${module.base.project_info.url}/blob/main/go.mod)"],
        [
          "[![Downloads](https://img.shields.io/github/downloads/${local.repo}/total?style=flat&label=downloads)](${module.base.project_info.url}/releases)",
          "[![OpenSSF Scorecard](https://api.securityscorecards.dev/projects/github.com/${local.repo}/badge)](https://scorecard.dev/viewer/?uri=github.com/${local.repo})",
        ],
        var.ci_workflow == null ? [] : ["[![CI](https://img.shields.io/github/actions/workflow/status/${local.repo}/${urlencode(var.ci_workflow)}?branch=main&style=flat&label=ci)](${module.base.project_info.url}/actions)"],
        [for m in var.go_modules : "[![Go Reference](https://pkg.go.dev/badge/${m}.svg)](https://pkg.go.dev/${m})"]
      )
    }
  )
}

output "workflow_files" {
  description = "Caller workflow files generated in .github/workflows/ by modules/workflows."
  value       = module.base.workflow_files
}
