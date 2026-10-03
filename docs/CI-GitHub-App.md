# CI GitHub App (`axnic-bot`)

`axnic-bot` is a dedicated GitHub App used exclusively by release workflows that
need to push version-bump commits directly to protected `main` branches. It is
registered as a bypass actor in every repository's branch ruleset, meaning it
can push without being blocked by `required_signatures` or required status
checks — while those rules remain in force for all human contributors.

> **Why not Terraform for the app itself?** GitHub Apps cannot be created via
> the Terraform GitHub provider — the GitHub API requires a web-based OAuth
> (Manifest flow), which is not automatable in HCL. Everything else — bypass
> actor registration and per-repo secrets — is fully managed by Terraform.

---

## Why a GitHub App and not a PAT?

|                        | Fine-grained PAT                | GitHub App                          |
| ---------------------- | ------------------------------- | ----------------------------------- |
| Tied to a user account | Yes — breaks if the user leaves | No — org-level identity             |
| Token lifetime         | Up to 1 year (long-lived)       | 1 hour (short-lived, auto-rotated)  |
| Audit trail            | Shows as the PAT owner          | Shows as `axnic-bot[bot]`           |
| Scope                  | Hard to restrict per repo       | Installed per repo, min permissions |

---

## 1. Create the GitHub App

Go to **github.com/organizations/axnic/settings/apps/new** and fill in:

| Field            | Value                      |
| ---------------- | -------------------------- |
| **App name**     | `axnic-bot`                |
| **Homepage URL** | `https://github.com/axnic` |
| **Webhooks**     | Uncheck _Active_           |

Under **Repository permissions**, set:

| Permission | Level                                                  |
| ---------- | ------------------------------------------------------ |
| Contents   | Read & write                                           |
| Workflows  | Read & write _(only if releases touch workflow files)_ |

Leave all other permissions at _No access_.

Click **Create GitHub App**. Note the **App ID** shown at the top of the app
settings page — you will need it in step 4.

---

## 2. Generate a private key

On the app settings page, scroll to **Private keys** and click
**Generate a private key**. A `.pem` file downloads automatically.

Keep this file safe — it is the only credential that lets workflows authenticate
as `axnic-bot`.

---

## 3. Install the app in the organisation

Still on the app settings page, click **Install App** in the left sidebar.
Choose the **axnic** organisation and select **All repositories** (or restrict
to specific ones — you can expand later).

After installation, the URL changes to something like:
`github.com/organizations/axnic/settings/installations/XXXXXXXX`

Note the **Installation ID** from that URL (`XXXXXXXX`).

---

## 4. Set Terraform Cloud workspace variables

In the **axnic / Github** workspace, add three variables:

| Variable                        | Value                            | Sensitive |
| ------------------------------- | -------------------------------- | --------- |
| `ci_github_app_id`              | App ID from step 1               | No        |
| `ci_github_app_installation_id` | Installation ID from step 3      | No        |
| `ci_github_app_pem_file`        | Full contents of the `.pem` file | **Yes**   |

Once set, open a PR — Terraform Cloud will plan:

- Registering `axnic-bot` as a bypass actor in each repo's branch ruleset.
- Creating `CI_APP_ID`, `CI_APP_INSTALLATION_ID`, and `CI_APP_PRIVATE_KEY`
  as Actions secrets on every repo that needs the bot.

Secrets are scoped **per repository** — not org-wide. Only repos listed in
`ci_bot_repos` in `terraform/live/ci_app.tf` receive them.

---

## 5. Use the app in a release workflow

Use [`actions/create-github-app-token`](https://github.com/actions/create-github-app-token)
to exchange the private key for a short-lived installation token, then
configure Git to use it before pushing.

```yaml
jobs:
  release:
    runs-on: ubuntu-latest
    permissions:
      contents: read # GITHUB_TOKEN only needs read; axnic-bot handles the push

    steps:
      - name: Generate CI app token
        id: app-token
        uses: actions/create-github-app-token@v1
        with:
          app-id: ${{ secrets.CI_APP_ID }}
          private-key: ${{ secrets.CI_APP_PRIVATE_KEY }}

      - uses: actions/checkout@v4
        with:
          token: ${{ steps.app-token.outputs.token }}

      # --- bump version, update changelog, etc. ---

      - name: Push release commit
        run: |
          git config user.name  "axnic-bot[bot]"
          git config user.email "axnic-bot[bot]@users.noreply.github.com"
          git add package.json
          git commit -m "chore(release): bump version to $VERSION"
          git push
```

> **Note:** The commit pushed this way is unsigned (no GPG/SSH signature).
> This is intentional — `axnic-bot` is a bypass actor in the ruleset, so
> `required_signatures` does not apply to its pushes. The commit is still
> attributed to `axnic-bot[bot]` and fully auditable in the git log.

---

## 6. How the bypass and secrets work in Terraform

`terraform/live/projects.tf` derives the bypass actor from the workspace variable:

```hcl
locals {
  ci_bypass_actors = var.ci_github_app_id != "" ? [{
    actor_id    = tonumber(var.ci_github_app_id)  # GitHub App ID, not installation ID
    actor_type  = "Integration"
    bypass_mode = "always"
  }] : []
}
```

`terraform/live/ci_app.tf` creates the repo-level secrets for every repo in
`ci_bot_repos`:

```hcl
locals {
  ci_bot_repos = var.ci_github_app_id != "" ? toset([
    module.pi_extension_settings.project_info.name,
    # add further repos here
  ]) : toset([])
}
```

When `ci_github_app_id` is empty (default), both lists are empty — no bypass
actor is registered and no secret is created.

## 7. Adding a new repo to the bot

When a new repository needs `axnic-bot`:

1. In `terraform/live/projects.tf`, pass the bypass actor to its module:

   ```hcl
   module "my_new_repo" {
     source = "../modules/repository/pi_extension"
     # ...
     ruleset_bypass_actors = local.ci_bypass_actors
   }
   ```

2. In `terraform/live/ci_app.tf`, add the repo to `ci_bot_repos`:

   ```hcl
   ci_bot_repos = var.ci_github_app_id != "" ? toset([
     module.pi_extension_settings.project_info.name,
     module.my_new_repo.project_info.name,  # ← add this
   ]) : toset([])
   ```

3. Open a PR — Terraform Cloud adds the bypass actor and creates the secrets.
