output "project_info" {
  description = "Standardised project metadata consumed by the org_readme module."

  value = merge(
    module.base.project_info,
    {
      type = "pi_extension"

      badges = concat(
        module.base.project_info.badges,
        [for pkg in var.npm_packages : "[![${reverse(split("/", pkg))[0]}](https://img.shields.io/npm/dm/${pkg}?style=flat&label=${reverse(split("/", pkg))[0]})](https://www.npmjs.com/package/${pkg})"]
      )
    }
  )
}
