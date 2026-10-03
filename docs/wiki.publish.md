# wiki.publish - Wiki

Group `wiki`. Central workflow: `.github/workflows/wiki.publish.yaml`.

## Purpose

Mirrors a docs directory of the repository to its GitHub Wiki (job `publish`, through
`Andrew-Chen-Wang/github-wiki-action`). This is how the pages you are reading are published. The caller
decides when it runs and should serialize runs with a `concurrency` group (`cancel-in-progress: false`).

How the mirroring behaves (read from the pinned version of the action):

- The wiki working tree is **emptied** and the directory is copied in: a page edited in the wiki UI, or a
  file removed from the directory, disappears from the wiki on the next run.
- The copy is recursive, but `README.md` renaming to `Home.md` and the rewriting of `.md` links to bare
  wiki links only apply to the Markdown files at the **top level** of the directory. GitHub serves wiki
  pages by base name.
- Hence the documentation of this repository is **flat** and links between pages are relative file names
  with the extension (`[core.qa](core.qa.md)`). See [Conventions](Conventions.md#documentation-pages).

## When it runs

Caller `push,workflow_dispatch.wiki.yaml`: `push` to the default branch on the docs paths, and on demand.

## Prerequisites

The wiki must be enabled and initialized (one page created by hand, once).

## Inputs

| Input      | Type   | Default | Notes                              |
| ---------- | ------ | ------- | ---------------------------------- |
| `docs-dir` | string | `docs`  | Directory mirrored to the wiki.    |

## Secrets

None.

## Permissions (granted by the caller)

`contents: write`

## Required mise tasks

None.

## Example caller

```yaml
name: Wiki

on:
  push:
    branches: ["main"]
    paths:
      - "docs/**"
      - ".github/workflows/push,workflow_dispatch.wiki.yaml"
  workflow_dispatch: {}

concurrency:
  group: wiki
  cancel-in-progress: false

# Minimal top-level permissions - each job declares what it needs.
permissions: {}

jobs:
  wiki:
    name: 📚 Publish Wiki
    # Intentionally not pinned: follows the latest axnic/.github (owner-controlled repo).
    uses: axnic/.github/.github/workflows/wiki.publish.yaml@main
    secrets: inherit
    permissions:
      contents: write
```

This repository calls it with a local reference (`uses: ./.github/workflows/wiki.publish.yaml`).

## Known limitations

- The banner example of the workflow lists only `docs/**` in `paths`; the Terraform module also adds the
  caller file itself.
- The wiki repository must already exist: the action does not create it.
- The behaviour of the link rewriting is taken from the action's source at its pinned SHA; the first
  publication should be checked in the wiki.
