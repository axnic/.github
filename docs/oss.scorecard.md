# oss.scorecard - OpenSSF Scorecard

Group `oss` (opt-in, public repositories). Central workflow: `.github/workflows/oss.scorecard.yaml`.

## Purpose

Runs OpenSSF Scorecard on the repository, publishes the result (badge and trending data) and uploads the
SARIF report to the Security tab. Job `scorecard`: the scorecard action, then the SARIF upload.

## When it runs

Caller `schedule,workflow_dispatch.scorecard.yaml`: a weekly `schedule` (Terraform setting
`scorecard_cron`) and on demand.

## Inputs

None.

## Secrets

None.

## Permissions (granted by the caller)

`contents: read`, `security-events: write`, `id-token: write`, `actions: read`

## Required mise tasks

None.

## Example caller

```yaml
name: OpenSSF Scorecard

on:
  schedule:
    - cron: "0 5 * * 1"
  workflow_dispatch: {}

# Minimal top-level permissions - each job declares what it needs.
permissions: {}

jobs:
  scorecard:
    name: 🛡️ OpenSSF Scorecard
    # Intentionally not pinned: follows the latest axnic/.github (owner-controlled repo).
    uses: axnic/.github/.github/workflows/oss.scorecard.yaml@main
    secrets: inherit
    permissions:
      actions: read
      contents: read
      id-token: write
      security-events: write
```

## Known limitations

- The scorecard action runs with `publish_results: true` from a reusable workflow. The Scorecard web
  service verifies the workflow it receives results from, and may reject a run whose workflow file is
  the caller's. This has not been proven yet; if the first real run is rejected, the options are to
  turn publishing off (an input) or to inline the job in the callers.
