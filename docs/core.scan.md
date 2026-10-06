# core.scan - Code Scanning

Group `core`. Central workflow: `.github/workflows/core.scan.yaml`.

## Purpose

Runs GitHub's CodeQL static analysis (SAST) with the `security-and-quality` query suite, one matrix leg
per language. Findings appear in the repository's Security tab. Callers should run it on every pull
request and push to the default branch, and on a daily schedule: a finding is reported on the change
that introduces it, the OpenSSF Scorecard SAST check is satisfied, and the schedule catches findings
from query updates on unchanged code.

It is skipped for Dependabot and for pull requests from forks: their token cannot write the
code-scanning results (`security-events: write`).

## When it runs

Caller `pull_request,push,schedule.scan.yaml`: `pull_request`, `push` to the default branch and a
`schedule` (the cron is set by the caller; Terraform setting `scan_cron`).

## Inputs

| Input       | Type   | Default    | Notes                                  |
| ----------- | ------ | ---------- | -------------------------------------- |
| `languages` | string | `["go"]`   | JSON array of CodeQL languages.        |

## Secrets

None.

## Permissions (granted by the caller)

`contents: read`, `security-events: write`, `actions: read`

## Required mise tasks

None.

## Example caller

```yaml
name: Code Scanning

on:
  pull_request: {}
  push:
    branches: ["main"]
  schedule:
    - cron: "0 6 * * *"

concurrency:
  group: scan-${{ github.event.pull_request.number || github.ref }}
  cancel-in-progress: true

# Minimal top-level permissions - each job declares what it needs.
permissions: {}

jobs:
  scan:
    name: 🧬 CodeQL
    # Pinned to the axnic/.github commit that last changed this workflow; Terraform keeps it up to date.
    uses: axnic/.github/.github/workflows/core.scan.yaml@<commit-sha> # main
    with:
      languages: '["go"]'
    secrets: inherit
    permissions:
      actions: read
      contents: read
      security-events: write
```

## Known limitations

- The languages are not detected: set `languages` for a repository that is not Go.
