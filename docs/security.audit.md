# security.audit - Dependency Audit

Group `security`. Central workflow: `.github/workflows/security.audit.yaml`.

## Purpose

Runs the repository's own audit task, whatever the ecosystems (`govulncheck` for Go, `npm audit`,
`pip-audit`, ...). What is audited is defined by the repository in its `security:audit` mise task; this
workflow only installs the tools and runs it.

## When it runs

Caller `schedule,workflow_dispatch.audit.yaml`: a daily `schedule` (Terraform setting `audit_cron`) and on
demand.

## Inputs

None.

## Secrets

None.

## Permissions (granted by the caller)

`contents: read`

## Required mise tasks

`security:audit` (required). See [Mise-Tasks](Mise-Tasks.md) for a Go and a Pulumi example.

## Example caller

```yaml
name: Dependency Audit

on:
  schedule:
    - cron: "0 6 * * *"
  workflow_dispatch: {}

# Minimal top-level permissions - each job declares what it needs.
permissions: {}

jobs:
  audit:
    name: 📦 Dependency Audit
    # Pinned to the axnic/.github commit that last changed this workflow; Terraform keeps it up to date.
    uses: axnic/.github/.github/workflows/security.audit.yaml@<commit-sha> # main
    secrets: inherit
    permissions:
      contents: read
```

## Known limitations

- The workflow has no concurrency group.
- The audit is only as complete as the task: a language the task does not cover is not audited.
