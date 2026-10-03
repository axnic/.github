# e2e.sync - E2E Sync

Group `e2e`. Central workflow: `.github/workflows/e2e.sync.yaml`.

## Purpose

Adds the E2E caller, and the README badge, of every new version to test. It asks the repository which
versions to cover (`mise run ci:e2e:versions`, one exact version per line, the same string the `ci:e2e`
task gets as `E2E_VERSION`), and for each version without a
`merge_group,pull_request,push.e2e-<version>.yaml` caller in `.github/workflows/`:

- creates the caller from `.github/templates/e2e-caller.yaml.tmpl` of this repository (placeholder
  `__VERSION__`);
- adds a badge row after the last row of the README's E2E badge table, in the format of the existing rows
  (no E2E badge table in the README = README left alone);
- commits on the stable branch `ci/e2e-sync` and opens a pull request, or updates the open one. The branch
  is rebuilt from the default branch with all currently missing versions and force-pushed with
  `--force-with-lease`. Nothing missing = the run ends successfully and touches nothing.

Versions are validated against `^[A-Za-z0-9._-]+$` before use, since they become file and branch names.
The commit is DCO signed-off.

## When it runs

Caller `schedule,workflow_dispatch.e2e-sync.yaml`: a weekly `schedule` (Terraform setting `e2e_sync_cron`)
and on demand.

## Prerequisites

- The repository setting "Allow GitHub Actions to create and approve pull requests".
- `GITHUB_TOKEN` can never push files under `.github/workflows/` (it has no `workflows` permission). The
  workflow therefore mints a token from the `axnic-bot` GitHub App when `CI_APP_ID` and
  `CI_APP_PRIVATE_KEY` are both set; the app needs `contents: write`, `pull-requests: write` and
  `workflows: write` on the repository. Without them it falls back to `GITHUB_TOKEN` with a warning and
  the push is refused. A pull request opened with `GITHUB_TOKEN` also does not trigger the
  `pull_request` workflows (an App token does). See [Adding-A-Repo](Adding-A-Repo.md).

## Inputs

| Input            | Type   | Default                      | Notes                                                                             |
| ---------------- | ------ | ---------------------------- | --------------------------------------------------------------------------------- |
| `readme-path`    | string | `README.md`                  | README holding the E2E badge table.                                               |
| `commit-subject` | string | `ci(ci): Sync E2E callers`   | Commit subject and PR title; must satisfy the repository's commitlint (mandatory scope). |

## Secrets

| Secret               | Required | Notes                                                       |
| -------------------- | -------- | ----------------------------------------------------------- |
| `CI_APP_ID`          | no       | With `CI_APP_PRIVATE_KEY`: mint a token of the GitHub App.   |
| `CI_APP_PRIVATE_KEY` | no       | See above; fallback `GITHUB_TOKEN` with a warning.           |

## Permissions (granted by the caller)

`contents: write`, `pull-requests: write`

## Required mise tasks

`ci:e2e:versions` (required): print only the versions on stdout, one per line. See
[Mise-Tasks](Mise-Tasks.md).

## Example caller

```yaml
name: E2E Sync

on:
  schedule:
    - cron: "0 3 * * 1"
  workflow_dispatch: {}

concurrency:
  group: e2e-sync
  cancel-in-progress: false

# Minimal top-level permissions - each job declares what it needs.
permissions: {}

jobs:
  sync:
    name: 🔄 Sync E2E callers
    # Intentionally not pinned: follows the latest axnic/.github (owner-controlled repo).
    uses: axnic/.github/.github/workflows/e2e.sync.yaml@main
    with:
      commit-subject: ci(ci): Sync E2E callers
    secrets: inherit
    permissions:
      contents: write
      pull-requests: write
```

## Known limitations

- The default `commit-subject` (`ci(ci): ...`) is only valid for repositories whose commitlint scope enum
  contains `ci`; others set it (rtunk does).
- An open sync pull request has its body overwritten with the set of versions missing at the time of the
  run.
- The commit is signed off but not GPG-signed; a repository that requires signed commits needs a squash
  merge of the pull request.
- The sparse checkout, the `--force-with-lease` push and the App token path can only be proven on a real
  run.
- Existing hand-written E2E callers are not recognised as generated: they differ in banner and job name
  from the template.
