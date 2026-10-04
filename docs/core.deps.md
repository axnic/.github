# core.deps - Dependency Updates

Group `core`. Central workflow: `.github/workflows/core.deps.yaml`.

## Purpose

Auto-merge of the dependency bots' own pull requests. The caller must trigger it on `pull_request`, not
`pull_request_target`: bot pull requests are same-repository, never a fork. One job per bot, selected by
`github.actor`.

### `auto-merge` - Dependabot

Dependabot only opens security updates once `dependabot.yml` is gone (Dependabot alerts and security
updates stay enabled, see [Renovate](Renovate.md)).

1. Reads the update's semver level and any associated GHSA advisory (`dependabot/fetch-metadata`).
2. For **patch** updates, or a **security** update at any semver level, approves the pull request and
   enables GitHub's native auto-merge with an explicit, convention-compliant subject
   `<subject-prefix>: Bump <dependencies> from <old> to <new>` (Dependabot's own commit text never
   follows the convention).
3. Minor and major, non-security updates are left untouched, open for manual review.

### `renovate` - Renovate

The policy lives in the Renovate presets of this repository (`default.json`, `pulumi.json`), not here:
Renovate marks the pull requests that may be merged automatically with `<!-- axnic:auto-merge -->` in
the body. They are patches, minors of versions from 1.0 on (grouped or not) and security updates (opened
from the Dependabot alerts, labelled `type::security`). Minors of 0.x versions and majors never carry the
marker.

1. Only pull requests opened and pushed by `renovate-actor` are considered.
2. Reads the live pull request (title, body, files), since Renovate edits it after opening it.
3. With the marker: approves it and enables GitHub's native auto-merge, with the **pull request title**
   as the subject. The title is already convention-compliant (semantic commits, sentence-case) and,
   unlike Dependabot's, is valid for a grouped pull request. It must start with `<subject-prefix>` followed by a colon and a space;
   otherwise the job **fails** rather than queue a subject that commitlint would reject on the default
   branch.
4. Without the marker: nothing happens, the pull request stays open for review.

### Both jobs

A pull request that edits a workflow file (a `github-actions` update) is approved but **never
auto-merged**: `GITHUB_TOKEN` can never merge a commit that touches `.github/workflows/**`. It stays open
for a human. With `merge` the subject is the merge commit's title, with `squash` the squash commit's
title; the body is left empty in both cases.

GitHub's auto-merge only takes effect once the required status checks succeed, so the workflow can run
immediately.

## When it runs

Caller `pull_request.deps.yaml`, on `pull_request` to the default branch.

## Prerequisites

The repository setting "Allow auto-merge", the chosen merge method allowed on the repository (the
Terraform repository modules only allow merge commits), and the required status checks of the default
branch. For Renovate: the Renovate GitHub App installed on the repository and a `renovate.json` extending
`local>axnic/.github:default` (or `:pulumi`).

## Inputs

| Input            | Type   | Default         | Notes                                                                                                           |
| ---------------- | ------ | --------------- | --------------------------------------------------------------------------------------------------------------- |
| `subject-prefix` | string | `build(deps)`   | What precedes the colon in the merge subject; must match the repository's commit convention (rtunk: `^[deps]`). |
| `merge-method`   | string | `merge`         | `merge` or `squash`; anything else fails the job. Must be a method the repository allows.                       |
| `renovate-actor` | string | `renovate[bot]` | Login of the Renovate bot (hosted Mend app). Change it only for a self-hosted Renovate.                         |

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
    name: 🤖 Dependency Auto-merge
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

- `subject-prefix` is not validated: an empty value gives the subject `: Bump ...` (Dependabot) or fails
  the job (Renovate).
- Dependabot pull requests skip `commitlint` in [core.qa](core.qa.md); Renovate ones do not: its commits
  (made through the GitHub API, hence signed) must follow the convention, which checks the preset.
- The marker is written by the preset; a repository that adds its own grouping rules must not mix majors
  or 0.x minors into a group that carries it.
- Both bots can open a pull request for the same security alert while Dependabot security updates are
  enabled on the repository (`security_features` contains `dependabot`).
