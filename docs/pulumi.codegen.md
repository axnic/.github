# pulumi.codegen - Codegen Check

Group `pulumi` (or enabled alone with `workflows = [{ workflow = "pulumi.codegen" }]`). Central workflow:
`.github/workflows/pulumi.codegen.yaml`.

## Purpose

For Pulumi provider repositories. The language SDKs under `sdk/` are generated from the provider schema
(`provider/cmd/<binary>/schema.json`) by `make codegen`; a contributor who edits `sdk/` by hand would see
the change overwritten by the next codegen.

Job `warn`: when a pull request **from a fork** changes files under `sdk/` but **no** `schema.json`, it
posts one comment asking the author to change the provider code and regenerate instead. Same-repository
pull requests (maintainers, Dependabot) get no comment. It does not warn about schema changes
themselves.

`pull_request_target` runs with a write token in the base repository: nothing of the pull request is
checked out or executed. The changed file names come from the GitHub API and the comment text is fixed.

## When it runs

Caller `pull_request_target.codegen.yaml`, on `pull_request_target` to the default branch, type `opened`.

## Inputs

None.

## Secrets

None (uses `GITHUB_TOKEN`).

## Permissions (granted by the caller)

`contents: read`, `pull-requests: write`

## Required mise tasks

None.

## Example caller

```yaml
name: Codegen Check

on:
  pull_request_target:
    branches: ["main"]
    types: [opened]

# Minimal top-level permissions - each job declares what it needs.
permissions: {}

jobs:
  codegen:
    name: 🧩 Codegen Check
    # Intentionally not pinned: follows the latest axnic/.github (owner-controlled repo).
    uses: axnic/.github/.github/workflows/pulumi.codegen.yaml@main
    secrets: inherit
    permissions:
      contents: read
      pull-requests: write
```

## Known limitations

- It keeps the behaviour of the former `community-moderation` workflow (warn on hand-edited generated
  code), not the reverse check "schema changed but `sdk/` not regenerated".
- The comment links to `CONTRIBUTING.md#building-and-generating-the-sdks` on the default branch, a section
  that the repositories are expected to have.
