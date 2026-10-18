locals {
  pi_extensions = [for p in var.projects : p if p.type == "pi_extension"]
  pulumi        = [for p in var.projects : p if p.type == "pulumi"]
  n8n           = [for p in var.projects : p if p.type == "n8n_extension"]
  # Go has no group of its own: go and untyped repos land here.
  others = [for p in var.projects : p if !contains(["pi_extension", "pulumi", "n8n_extension"], p.type)]

  # Private profile sections, in display order: the extensions of other tools first.
  sections = [
    { title = "Pulumi Providers", intro = "Pulumi providers for self-hosted services.", projects = local.pulumi },
    { title = "n8n Extensions", intro = "Community nodes that plug self-hosted services into n8n workflows.", projects = local.n8n },
    { title = "π｜Pi-agent Extensions", intro = "Standalone modules that extend pi-agent's capabilities — each ships as an independent, installable package.", projects = local.pi_extensions },
    { title = "Other Projects", intro = "Everything else.", projects = local.others },
  ]

  generated_at = formatdate("DD MMM YYYY", timestamp())

  public_content = templatefile("${path.module}/templates/public.md.tftpl", {
    public_links = var.public_links
    generated_at = local.generated_at

    pi_extensions = local.pi_extensions
  })

  private_content = templatefile("${path.module}/templates/private.md.tftpl", {
    public_links  = var.public_links
    private_links = var.private_links
    generated_at  = local.generated_at

    sections     = local.sections
    all_projects = var.projects
  })
}
