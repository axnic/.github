locals {
  featured = [for n in var.featured : one([for p in var.projects : p if p.name == n])]
  rest     = [for p in var.projects : p if !contains(var.featured, p.name)]
  pulumi   = [for p in local.rest : p if p.type == "pulumi"]
  n8n      = [for p in local.rest : p if p.type == "n8n_extension"]
  # Go has no group of its own: go and untyped repos land here. The Pi extensions are not listed.
  others = [for p in local.rest : p if !contains(["pi_extension", "pulumi", "n8n_extension"], p.type)]

  # Private profile sections, in display order: the featured projects, then the extensions of other tools.
  sections = [
    { title = "Featured", intro = "The projects I put the most into.", projects = local.featured },
    { title = "Pulumi Providers", intro = "Pulumi providers for self-hosted services.", projects = local.pulumi },
    { title = "n8n Extensions", intro = "Community nodes that plug self-hosted services into n8n workflows.", projects = local.n8n },
    { title = "Other Projects", intro = "Everything else.", projects = local.others },
  ]

  generated_at = formatdate("DD MMM YYYY", timestamp())

  public_content = templatefile("${path.module}/templates/public.md.tftpl", {
    public_links = var.public_links
    generated_at = local.generated_at
  })

  private_content = templatefile("${path.module}/templates/private.md.tftpl", {
    public_links  = var.public_links
    private_links = var.private_links
    generated_at  = local.generated_at

    sections     = local.sections
    all_projects = var.projects
  })
}
