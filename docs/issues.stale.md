# issues.stale - Stale Issues

Group `issues` (opt-in; the repository must have the GitHub feature `issues`). Central workflow:
`.github/workflows/issues.stale.yaml`.

## Purpose

Labels issues without activity as stale and posts a comment asking whether they are still relevant, then
closes those that stay silent, using `pose/stale-issue-cleanup`. Pull requests are ignored. Issues with
at least 2 upvotes are exempt, as are issues carrying one of the `exempt-issue-labels`.

**This workflow really labels and closes issues.** The former Pulumi-generated stale workflows ran in
dry-run mode and never closed anything, so enabling the `issues` group is a conscious opt-in.

## When it runs

Caller `schedule,workflow_dispatch.stale.yaml`: a daily `schedule` (cron set by the caller, Terraform
setting `stale_cron`) and on demand.

## Inputs

| Input                 | Type   | Default | Notes                                                                                                                |
| --------------------- | ------ | ------- | -------------------------------------------------------------------------------------------------------------------- |
| `days-before-stale`   | number | `60`    | Days without activity before the warning.                                                                            |
| `days-before-close`   | number | `14`    | Days after the warning before closing.                                                                               |
| `exempt-issue-labels` | string | `''`    | Comma-separated labels that exempt an issue; empty = none. The old Pulumi value was `kind/enhancement,kind/task,kind/epic,kind/engineering,awaiting-upstream`. |
| `stale-issue-label`   | string | `''`    | Label applied to stale issues; empty = the action's default (`Stale`). The old Pulumi value was `awaiting-feedback`.  |

## Secrets

None (uses `GITHUB_TOKEN`).

## Permissions (granted by the caller)

`issues: write`

## Required mise tasks

None.

## Example caller

```yaml
name: Stale Issues

on:
  schedule:
    - cron: "30 1 * * *"
  workflow_dispatch: {}

# Minimal top-level permissions - each job declares what it needs.
permissions: {}

jobs:
  stale:
    name: 🗓️ Stale Issues
    # Intentionally not pinned: follows the latest axnic/.github (owner-controlled repo).
    uses: axnic/.github/.github/workflows/issues.stale.yaml@main
    secrets: inherit
    permissions:
      issues: write
```

## Known limitations

- The Terraform `settings` only expose `stale_days` and `stale_close_days`; `exempt-issue-labels` and
  `stale-issue-label` are not settable from the module (use a custom caller if needed).
- The wording of the stale comment is this repository's own; the previous workflows used a different
  "ancient" model (180 days, then close) that is not reproduced.
- The `pose/stale-issue-cleanup` pin has no tag comment.
