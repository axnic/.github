# core.deps - Dependency Updates

Group `core`. Central workflow: `.github/workflows/core.deps.yaml`.

## Purpose

Auto-merge of Dependabot's own pull requests (`github.actor` is Dependabot). The caller must trigger
it on `pull_request`, not `pull_request_target`: Dependabot pull requests are same-repository, never a
fork.

1. Reads the update's semver level and any associated GHSA advisory (`dependabot/fetch-metadata`).
2. For **patch** updates, or a **security** update at any semver level, approves the pull request and
   enables GitHub's native auto-merge with an explicit, convention-compliant subject
   `<subject-prefix>: Bump <dependencies> from <old> to <new>` (Dependabot's own commit text never
   follows the convention). With `merge` the subject is the merge commit's title, with `squash` the
   squash commit's title; the body is left empty in both cases.
3. Minor and major, non-security updates are left untouched, open for manual review.
4. Updates of the `github-actions` ecosystem are approved but **never auto-merged**: their diff edits a
   workflow file's `uses:` line, and `GITHUB_TOKEN` can never merge a commit that touches
   `.github/workflows/**`. They stay open for a human.

GitHub's auto-merge only takes effect once the required status checks succeed, so the workflow can run
immediately.

## When it runs

Caller `pull_request.deps.yaml`, on `pull_request` to the default branch.

## Prerequisites

The repository setting "Allow auto-merge" (merge commits allowed), and the required status checks of
the default branch.

## Inputs

| Input            | Type   | Default       | Notes                                                                                           |
| ---------------- | ------ | ------------- | ----------------------------------------------------------------------------------------------- |
| `subject-prefix` | string | `build(deps)` | What precedes `: Bump ...`; must match the repository's commit convention (rtunk: `^[deps]`).    |
| `merge-method`   | string | `merge`       | `merge` or `squash` (Pulumi repositories use `squash`); anything else fails the job.             |

## Secrets

None (uses `GITHUB_TOKEN`).

## Permissions (granted by the caller)

`contents: write`, `pull-requests: write`

## Required mise tasks

None.

## Example caller

```yaml
name: Dependency Updates

on:
  pull_request:
    branches: ["main"]

# Minimal top-level permissions - each job declares what it needs.
permissions: {}

jobs:
  deps:
    name: 🤖 Dependabot Auto-merge
    # Intentionally not pinned: follows the latest axnic/.github (owner-controlled repo).
    uses: axnic/.github/.github/workflows/core.deps.yaml@main
    with:
      subject-prefix: build(deps)
      merge-method: merge
    secrets: inherit
    permissions:
      contents: write
      pull-requests: write
```

## Known limitations

- `subject-prefix` is not validated: an empty value gives the subject `: Bump ...`.
- Dependabot pull requests skip commitlint in [core.qa](core.qa.md); the subject set here is what is
  validated on `push`.
