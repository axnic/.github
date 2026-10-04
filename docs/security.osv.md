# security.osv - OSV-Scanner

Group `security`. Central workflow: `.github/workflows/security.osv.yaml`.

## Purpose

Scans the repository's manifests and lockfiles (`go.mod`, `go.sum`, `yarn.lock`, `package-lock.json`, ...)
with [OSV-Scanner](https://osv.dev) and uploads the findings as SARIF, so they appear in the Security tab
(code scanning) next to CodeQL. It complements [security.audit](security.audit.md) (the repository's own
`govulncheck`, `yarn audit`, ...), whose results only stay in the job log. The scan is Google's reusable
workflows (`google/osv-scanner-action`), pinned by commit; Renovate keeps the pin up to date.

| Job       | When           | What                                                                                 |
| --------- | -------------- | ------------------------------------------------------------------------------------ |
| `scan`    | push, schedule | Full scan of the default branch. Reported in code scanning, never fails the run.     |
| `pr-scan` | pull request   | Only the vulnerabilities the pull request introduces; fails on any (`fail-on-vuln`). |

Existing vulnerabilities therefore never block an unrelated pull request. The pull request scan is
skipped for Dependabot and for forks, whose token cannot write code-scanning results; Renovate's pull
requests are scanned.

## When it runs

Caller `pull_request,push,schedule.osv.yaml`: every pull request, every push to the default branch and a
weekly `schedule` (Terraform setting `osv_cron`, Monday 05:30 UTC by default).

## Inputs

| Input          | Type    | Default     | Notes                                                                     |
| -------------- | ------- | ----------- | ------------------------------------------------------------------------- |
| `scan-args`    | string  | `-r` / `./` | `osv-scanner` arguments, one per line. `--format` and `--output` are set. |
| `fail-on-vuln` | boolean | `true`      | Fail the pull request scan on a newly introduced vulnerability.           |

## Secrets

None.

## Permissions (granted by the caller)

`actions: read`, `contents: read`, `security-events: write`

## Required mise tasks

None.

## Example caller

```yaml
name: OSV-Scanner

on:
  pull_request: {}
  push:
    branches: ["main"]
  schedule:
    - cron: "30 5 * * 1"

# Minimal top-level permissions - each job declares what it needs.
permissions: {}

jobs:
  osv:
    name: 🛡️ OSV-Scanner
    # Intentionally not pinned: follows the latest axnic/.github (owner-controlled repo).
    uses: axnic/.github/.github/workflows/security.osv.yaml@main
    secrets: inherit
    permissions:
      actions: read
      contents: read
      security-events: write
```

## Known limitations

- The organisation's allowed-actions policy must allow `google/osv-scanner-action`.
- The repositories that run the `osv-scanner` linter through rtunk scan the same lockfiles locally; this
  workflow is what feeds the Security tab.
