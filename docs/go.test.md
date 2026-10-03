# go.test - Quality Assurance (Go)

Group `go` (included by `pulumi`). Central workflow: `.github/workflows/go.test.yaml`.

## Purpose

Build, tests and coverage floor of a Go repository. Every job calls a `ci:*` mise task, so
`mise run ci` locally is the same gate. The caller is displayed as **Quality Assurance**, like
[core.qa](core.qa.md) (their concurrency groups differ: this one is prefixed with `go-test-`).

| Job     | What it does                                                                                                                                                                  |
| ------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `build` | `mise run ci:build`, on Linux.                                                                                                                                                |
| `test`  | `mise run ci:test` then `mise run ci:coverage` (the coverage floor), once per OS of the `os` input. Every leg runs to completion (`fail-fast: false`), so one platform's failure does not hide the other's. `ci:coverage` runs after `ci:test` in the same job, so it may read the profile `ci:test` wrote. |

## When it runs

Caller `pull_request,push.test.yaml`, on `pull_request` and `push` to the default branch, filtered to
the Go files (Terraform setting `go_paths`, default `**.go`, `go.mod`, `go.sum`) and to the caller file
itself.

## Inputs

| Input | Type   | Default                                | Notes                                         |
| ----- | ------ | -------------------------------------- | --------------------------------------------- |
| `os`  | string | `["ubuntu-latest","macos-latest"]`     | JSON array of runner labels for the `test` job. |

## Secrets

None.

## Permissions (granted by the caller)

`contents: read`

## Required mise tasks

`ci:build`, `ci:test`, `ci:coverage` (all required). See [Mise-Tasks](Mise-Tasks.md).

## Example caller

```yaml
name: Quality Assurance

on:
  pull_request:
    paths:
      - "**.go"
      - "go.mod"
      - "go.sum"
      - ".github/workflows/pull_request,push.test.yaml"
  push:
    branches: ["main"]
    paths:
      - "**.go"
      - "go.mod"
      - "go.sum"
      - ".github/workflows/pull_request,push.test.yaml"

concurrency:
  group: test-${{ github.event.pull_request.number || github.ref }}
  cancel-in-progress: true

# Minimal top-level permissions - each job declares what it needs.
permissions: {}

jobs:
  test:
    name: 🧪 Go
    # Intentionally not pinned: follows the latest axnic/.github (owner-controlled repo).
    uses: axnic/.github/.github/workflows/go.test.yaml@main
    secrets: inherit
    permissions:
      contents: read
```

## Known limitations

- The `Example call` in the workflow banner shows `merge_group,pull_request,push.test.yaml`; the Terraform
  module generates `pull_request,push.test.yaml` with path filters and no `merge_group`. The module is
  what ends up in the repositories.
- `ci:coverage` must not depend on `ci:test`, otherwise the tests run twice.
