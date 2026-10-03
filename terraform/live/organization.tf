# Org profile — generates and commits public + private README pages.
# Content is driven by local.all_projects declared in projects.tf.

module "org_readme" {
  source = "../modules/org_readme"

  projects = local.all_projects

  public_links  = []
  private_links = []

  # Ensure both target repositories exist before attempting to write files into them.
  depends_on = [github_repository.dot_github, github_repository.dot_github_private]
}
