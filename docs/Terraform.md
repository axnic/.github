# Terraform

The `terraform/` directory of this repository manages the **axnic** organisation as code: its
repositories, their security settings, the central CI callers, the AI-review keys and the
organisation profile. It is the showcase of how the organisation is run, and the reason the
[central workflows](Central-CI.md) reach every repository without a hand-written file.

It is applied by **HCP Terraform** (organisation `axnic`, workspace `Github`), connected to this
repository: a pull request gets a speculative plan, a merge on `main` is applied. Locally, Terraform
is only used to format, validate and test.

## What it manages

| Area                 | Where                                      | What                                                                                                       |
| -------------------- | ------------------------------------------ | ---------------------------------------------------------------------------------------------------------- |
| Repositories         | `live/projects.tf`, `modules/repository/*` | One module per repository type (`base`, `go`, `pulumi`, `pi_extension`): settings, rulesets, security      |
| Central CI callers   | `modules/workflows`                        | Writes the caller workflow of each repository, per group, and checks the mise tasks it needs               |
| AI review            | `modules/pr_agent`                         | A budget-capped OpenRouter key and an allow-list of users per repository                                   |
| CI app secrets       | `live/ci_app.tf`                           | The release bot credentials, scoped to the repositories that need them ([CI-GitHub-App](CI-GitHub-App.md)) |
| Organisation profile | `modules/org_readme`                       | The README of the organisation, rendered from the list of projects                                         |

The caller templates are in `.github/workflows/templates/`, next to the workflows they call.

## Secrets

No secret is in the repository. The GitHub App credentials and the OpenRouter management key are
**sensitive workspace variables** in HCP Terraform, and the state lives there, encrypted.

## Working on it

```sh
mise run tf:fmt         # check formatting
mise run tf:validate    # init without backend, validate terraform/live
mise run tf:test        # terraform test (mocked providers, no credentials)
```

The same three checks run on pull requests (`merge_group,pull_request,push.qa.yaml`), on every change. Never run `terraform apply` locally.

To add a repository, or to enable a group of workflows for one, see [Adding-A-Repo](Adding-A-Repo.md).
The first-time setup of the workspace and of the GitHub App is described in
[`terraform/bootstrap/README.md`](https://github.com/axnic/.github/blob/main/terraform/bootstrap/README.md).
