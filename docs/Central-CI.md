# Central CI

This repository hosts the **reusable GitHub Actions workflows** shared by the repositories of the
axnic organisation. This page explains how they are wired; the pages of each workflow are listed below.

## How it fits together

| Where                            | What                                                                                                                                                                                                                          |
| -------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `.github/workflows/` (this repo) | The reusable workflows (`on: workflow_call` only, no business trigger), the E2E caller template, the release scripts and prompt, and this documentation.                                                                      |
| `terraform/` (this repo)         | Terraform (HCP Terraform workspace `Github`, see [Terraform](Terraform.md)). Its `workflows` module **generates the caller workflow** of each repository, per group, and checks that the mise tasks the groups require exist. |
| Each application repository      | Its own `ci:*` mise tasks (see [Mise-Tasks](Mise-Tasks.md)) and its `.rtunk/` configuration. It holds no hand-written workflow for what a group already covers.                                                               |

A caller is a short workflow file written to the repository's default branch by Terraform. It
declares the triggers, grants the permissions, and calls one central workflow:

```yaml
jobs:
  qa:
    # Pinned to the axnic/.github commit that last changed this workflow; Terraform keeps it up to date.
    uses: axnic/.github/.github/workflows/core.qa.yaml@<commit-sha> # main
    secrets: inherit
    permissions:
      contents: read
```

Callers must not be edited by hand: the next Terraform apply overwrites them. To change what a
repository runs, change its Terraform configuration ([Adding-A-Repo](Adding-A-Repo.md)). The same
repository also contains hand-written callers for its own CI (see [Conventions](Conventions.md)).

## Pages

General:

- [Conventions](Conventions.md): file naming, house style, why callers follow `@main`, security rules,
  commit conventions.
- [Mise-Tasks](Mise-Tasks.md): the mise tasks a repository must define, and which workflow needs which.
- [Renovate](Renovate.md): the shared Renovate presets and how dependency updates are merged.
- [Releases](Releases.md): the two-stage release, recovery, verification of the artifacts.
- [Adding-A-Repo](Adding-A-Repo.md): enabling groups for a repository in Terraform, and the manual prerequisites.

Workflows, by group:

| Group      | Workflows                                                                                                   |
| ---------- | ----------------------------------------------------------------------------------------------------------- |
| `core`     | [core.qa](core.qa.md), [core.review](core.review.md), [core.scan](core.scan.md)                             |
| `issues`   | [issues.stale](issues.stale.md) (opt-in)                                                                    |
| `go`       | [go.test](go.test.md), [go.publish](go.publish.md)                                                          |
| `release`  | [release.prepare](release.prepare.md)                                                                       |
| `pulumi`   | [pulumi.publish](pulumi.publish.md), [pulumi.codegen](pulumi.codegen.md) (the `pulumi` group includes `go`) |
| `security` | [security.audit](security.audit.md), [security.osv](security.osv.md)                                        |
| `oss`      | [oss.scorecard](oss.scorecard.md), [oss.welcome](oss.welcome.md) (opt-in, public repositories)              |
| `e2e`      | [e2e.run](e2e.run.md), [e2e.sync](e2e.sync.md)                                                              |
| `wiki`     | [wiki.publish](wiki.publish.md)                                                                             |

Each page documents what the workflow file declares today (inputs, secrets, permissions): the
banner at the top of every workflow file is the reference if a page ever lags behind.
