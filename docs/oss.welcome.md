# oss.welcome - Contributor Welcome

Group `oss` (opt-in, public repositories). Central workflow: `.github/workflows/oss.welcome.yaml`.

## Purpose

Posts a comment on pull requests opened **from a fork**, to guide external contributors. Job `welcome`;
it is skipped when the pull request comes from the same repository.

The caller triggers on `pull_request_target` because the token must be able to write on fork pull
requests. That trigger runs with write access, so this workflow never checks out or executes code from
the pull request: it only posts a comment, and `inputs.message` is only used in `with:`, never in a shell.

## When it runs

Caller `pull_request_target.welcome.yaml`, on `pull_request_target`, type `opened`.

## Inputs

| Input     | Type   | Default | Notes                                           |
| --------- | ------ | ------- | ----------------------------------------------- |
| `message` | string | `''`    | Comment body; empty uses the built-in text (Terraform setting `welcome_message`). |

## Secrets

None (uses `GITHUB_TOKEN`).

## Permissions (granted by the caller)

`pull-requests: write`

## Required mise tasks

None.

## Example caller

```yaml
name: Contributor Welcome

on:
  pull_request_target:
    types: [opened]

# Minimal top-level permissions - each job declares what it needs.
permissions: {}

jobs:
  welcome:
    name: 👋 Welcome
    # Pinned to the axnic/.github commit that last changed this workflow; Terraform keeps it up to date.
    uses: axnic/.github/.github/workflows/oss.welcome.yaml@<commit-sha> # main
    secrets: inherit
    permissions:
      pull-requests: write
```

## Known limitations

- The built-in text is a generic English greeting written for this repository. The former workflow
  mentioned a `/run-acceptance-tests` command, which no workflow handles, so that sentence was dropped.
