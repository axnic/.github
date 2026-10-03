# Bootstrap — First-Time TFC + GitHub App Setup

Manual steps to run **once** before the VCS-driven Terraform Cloud workflow takes over.
After completing this guide every `terraform/` change goes through TFC automatically.

---

## 1 — Create a GitHub App (provider auth)

The `terraform/live/` config authenticates against GitHub via a GitHub App instead of a PAT.

1. Go to **GitHub → Organisation Settings → Developer settings → GitHub Apps → New GitHub App**
2. Fill in the basic info:
   - **GitHub App name:** `axnic-terraform` (must be globally unique)
   - **Homepage URL:** `https://github.com/axnic`
   - **Webhook → Active:** uncheck (not needed)
3. Set **Repository permissions:**
   | Permission | Access |
   | -------------------- | --------------- |
   | Administration | Read & write |
   | Contents | Read & write |
   | Metadata | Read-only |
   | Pull requests | Read & write |
   | Commit statuses | Read & write |
4. Set **Organisation permissions:**
   | Permission | Access |
   | -------------- | ------------ |
   | Administration | Read & write |
   | Members | Read-only |
5. **Where can this app be installed?** → Only on this account
6. Click **Create GitHub App**
7. On the app settings page, copy and save the **App ID**
8. Scroll down → **Generate a private key** → save the downloaded `.pem` file
9. Click **Install App** → install on the `axnic` org → All repositories
10. After install, open the installation page and note the **Installation ID**
    from the URL: `…/organizations/axnic/settings/installations/<INSTALLATION_ID>`

---

## 2 — Install the TFC GitHub App (VCS integration)

TFC needs its own GitHub App to trigger workspace runs on push/PR.

1. Log in to [app.terraform.io](https://app.terraform.io)
2. Go to **Organisation Settings → Version Control → GitHub App → Install**
3. Authorise the TFC app on the `axnic` organisation
4. After install, note the **Installation ID** from GitHub:
   `…/organizations/axnic/settings/installations/<INSTALLATION_ID>`

---

## 3 — Create the TFC workspace

1. Log in to [app.terraform.io](https://app.terraform.io) → organisation `axnic`
2. Go to **Projects & Workspaces → New Workspace**
3. Choose **Version Control Workflow**
4. Select the GitHub App VCS connection → pick the `axnic/.github` repository
5. Configure the workspace:
   | Setting | Value |
   | -------------------- | ---------------- |
   | Workspace name | `Github` |
   | Project | Default |
   | Terraform version | `>= 1.9` |
   | Working directory | `terraform/live` |
   | Auto-apply | Enabled |
   | Trigger: VCS prefixes | `terraform/`, `.github/workflows/templates/` |

   > The trigger prefixes are a manual workspace setting (Settings → Version Control →
   > "Only trigger runs when files in specified paths change"). Keep
   > `.github/workflows/templates/` in the list: the caller templates of
   > `modules/workflows` live there, and a change to them must start a plan.

---

## 4 — Set workspace variables in TFC

Open the `Github` workspace → **Variables** → add the following
**Terraform variables** (use the values from Step 1):

| Variable                     | Value                  | Sensitive |
| ---------------------------- | ---------------------- | --------- |
| `github_app_id`              | App ID                 | No        |
| `github_app_installation_id` | Installation ID        | No        |
| `github_app_pem_file`        | Full PEM file contents | **Yes**   |

> Paste the entire PEM including `-----BEGIN RSA PRIVATE KEY-----` and
> `-----END RSA PRIVATE KEY-----` lines.

---

## 5 — Migrate state (if upgrading from `github-org-config`)

If the old workspace has existing state, migrate it before the first VCS-triggered run:

```sh
# Authenticate
terraform login

# Pull state from the old workspace
cd terraform/live
TF_WORKSPACE=github-org-config terraform state pull > /tmp/old-state.json

# Point to the new workspace (versions.tf already updated)
terraform init          # confirms workspace is "Github"

# Push state into the new workspace
terraform state push /tmp/old-state.json
```

For a **fresh start** (no prior state), just run `terraform init` in `terraform/live/` — TFC
will initialise an empty state automatically on the first VCS-triggered plan.

---

## 6 — Verify

Push any change to `terraform/` on a branch → TFC should post a speculative plan as a
PR check. Merge to `main` → TFC auto-applies.
