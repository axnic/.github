# Root entrypoint — wires together projects.tf (repositories) and organization.tf (org profile).
# These two repositories are managed directly here (not via modules) because they are
# org-infrastructure repos with non-standard configurations.

resource "github_repository" "dot_github" {
  name         = ".github"
  description  = "Repository for organization-wide configuration (issue templates, PR templates, GitHub Actions workflows, etc.) and the public org profile README."
  homepage_url = "https://github.com/axnic"

  visibility = "public"

  # ── Features ──────────────────────────────────────────────────────────────
  has_issues      = false
  has_discussions = false
  has_projects    = false
  # Central docs are published here by wiki.publish; create the first page in the UI once.
  has_wiki = true

  # ── Merge strategy ────────────────────────────────────────────────────────
  allow_merge_commit = true
  allow_squash_merge = false
  allow_rebase_merge = false
  allow_auto_merge   = true

  merge_commit_title     = "PR_TITLE"
  merge_commit_message   = "PR_BODY"
  delete_branch_on_merge = true

  # ── Security settings ─────────────────────────────────────────────────────
  web_commit_signoff_required = true
  vulnerability_alerts        = true

  # Prevent accidental deletion — archive first, then delete manually if needed.
  archive_on_destroy = true
  lifecycle {
    prevent_destroy = true
  }
}

# Writes the public org profile (visible at github.com/<org>)
resource "github_repository_file" "public_readme" {
  repository          = github_repository.dot_github.name
  branch              = "main"
  file                = "README.md"
  content             = module.org_readme.rendered_public
  commit_message      = "chore(docs): Update public organisation profile README"
  overwrite_on_create = true
}

resource "github_repository" "dot_github_private" {
  name         = ".github-private"
  description  = "Private repository for internal-only documentation and the private org profile README. This repo also manages all Github organization configuration through Terraform"
  homepage_url = "https://github.com/axnic"

  visibility = "private"

  # ── Features ──────────────────────────────────────────────────────────────
  has_issues      = false
  has_discussions = false
  has_projects    = false
  has_wiki        = false

  # ── Merge strategy ────────────────────────────────────────────────────────
  allow_merge_commit = true
  allow_squash_merge = false
  allow_rebase_merge = false
  allow_auto_merge   = true

  merge_commit_title     = "PR_TITLE"
  merge_commit_message   = "PR_BODY"
  delete_branch_on_merge = true

  # ── Security settings ─────────────────────────────────────────────────────
  # security_and_analysis omitted — advanced_security requires a GHAS licence
  # which is not available for this org. Secret scanning and related features
  # are not applicable for this infrastructure repo.
  web_commit_signoff_required = true
  vulnerability_alerts        = true

  # Prevent accidental deletion — archive first, then delete manually if needed.
  archive_on_destroy = true
  lifecycle {
    prevent_destroy = true
  }
}

# Writes the private org profile (visible to org members at github.com/<org>)
resource "github_repository_file" "private_readme" {
  repository = github_repository.dot_github_private.name
  branch     = "main"
  file       = "README.md"
  content    = module.org_readme.rendered_private

  commit_message      = "chore(docs): Update private organisation profile README"
  overwrite_on_create = true
}
