locals {
  pi_extensions = [for p in var.projects : p if p.type == "pi_extension"]
  pulumi        = [for p in var.projects : p if p.type == "pulumi"]
  # Go has no group of its own: go and untyped repos land here.
  others = [for p in var.projects : p if !contains(["pi_extension", "pulumi"], p.type)]

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

    pi_extensions = local.pi_extensions
    pulumi        = local.pulumi
    others        = local.others
    all_projects  = var.projects
  })
}
