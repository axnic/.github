locals {
  repo = trimprefix(module.base.project_info.url, "https://github.com/")
}

output "project_info" {
  description = "Standardised project metadata consumed by the org_readme module."

  value = merge(
    module.base.project_info,
    {
      type = "pulumi"

      badges = concat(
        module.base.project_info.badges,
        [
          "[![Downloads](https://img.shields.io/github/downloads/${local.repo}/total?style=flat&label=downloads)](${module.base.project_info.url}/releases)",
          "[![OpenSSF Scorecard](https://api.securityscorecards.dev/projects/github.com/${local.repo}/badge)](https://scorecard.dev/viewer/?uri=github.com/${local.repo})",
        ],
        var.ci_workflow == null ? [] : ["[![CI](https://img.shields.io/github/actions/workflow/status/${local.repo}/${urlencode(var.ci_workflow)}?branch=main&style=flat&label=ci)](${module.base.project_info.url}/actions)"],
        [for p in var.npm_packages : "[![npm](https://img.shields.io/npm/dm/${p}?style=flat&label=npm%2Fmonth)](https://www.npmjs.com/package/${p})"],
        [for p in var.pypi_packages : "[![PyPI](https://img.shields.io/pypi/dm/${p}?style=flat&label=pypi%2Fmonth)](https://pypi.org/project/${p}/)"],
        [for p in var.nuget_packages : "[![NuGet](https://img.shields.io/nuget/dt/${p}?style=flat&label=nuget)](https://www.nuget.org/packages/${p})"],
        [for p in var.registry_packages : "[![Pulumi Registry](https://img.shields.io/badge/pulumi-${p}-8A3391?style=flat&logo=pulumi)](https://www.pulumi.com/registry/packages/${p}/)"]
      )
    }
  )
}

output "workflow_files" {
  description = "Caller workflow files generated in .github/workflows/ by modules/workflows."
  value       = module.base.workflow_files
}
