# core.review - AI Review

Group `core`, generated only for a repository that has an OpenRouter key (`pr_agent_enabled`).
Central workflow: `.github/workflows/core.review.yaml`.

## Purpose

Runs [PR Agent](https://docs.pr-agent.ai/installation/github/) as a GitHub Action, only when asked. The
model is reached through OpenRouter.

| Job        | What it does                                                                                                                                       |
| ---------- | -------------------------------------------------------------------------------------------------------------------------------------------------- |
| `welcome`  | When a pull request is opened, a comment lists the commands and how to use them. No model call; nothing from the pull request is executed.          |
| `pr-agent` | A comment starting with `/` (`/describe`, `/review`, `/improve`, `/ask ...`, `/help`) runs that command. Only the logins of the allow-list count, so nobody else can spend the key. |

Nothing runs automatically on pushes. PR Agent never edits the pull request's own title or
description: `/describe` posts its result as one persistent comment.

## When it runs

Caller `issue_comment,pull_request.review.yaml`: `pull_request` (`opened`) and `issue_comment`
(`created`). The caller's event must be `issue_comment`/`pull_request`, **never `pull_request_target`**:
PR Agent reads the diff through the GitHub API without a checkout, so a pull request's own code never
runs with secrets. Bots (Dependabot included) and pull requests from forks get no welcome comment, since
their token is read-only.

## Prerequisites

- The secret `OPENROUTER_API_KEY` (generated per repository by Terraform). Without it neither job does
  anything.
- The repository variable `PR_AGENT_ALLOWED_USERS` (Settings > Secrets and variables > Actions >
  Variables): a JSON list of GitHub logins such as `["alice", "bob"]`, compared case-insensitively.
  There is no fallback: while it is unset, nothing runs.

## Inputs

| Input            | Type   | Default                                        |
| ---------------- | ------ | ---------------------------------------------- |
| `model`          | string | `openrouter/unbiased/pareto-26.10-preview`     |
| `fallback-model` | string | `openrouter/anthropic/claude-sonnet-5.5`       |

## Secrets

| Secret               | Required | Notes                                      |
| -------------------- | -------- | ------------------------------------------ |
| `OPENROUTER_API_KEY` | no       | Without it the workflow does nothing.      |

## Permissions (granted by the caller)

`contents: read`, `issues: write`, `pull-requests: write`

## Required mise tasks

None.

## Example caller

```yaml
name: AI Review

on:
  issue_comment:
    types: [created]
  pull_request:
    types: [opened]

# Minimal top-level permissions - each job declares what it needs.
permissions: {}

jobs:
  review:
    name: 🤖 PR Agent
    # Intentionally not pinned: follows the latest axnic/.github (owner-controlled repo).
    uses: axnic/.github/.github/workflows/core.review.yaml@main
    secrets: inherit
    permissions:
      contents: read
      issues: write
      pull-requests: write
```

## Known limitations

- Both jobs require `vars.PR_AGENT_ALLOWED_USERS` to be non-empty; this prerequisite is not part of the
  original contract.
- The fallback model is passed as a one-element list built from the `fallback-model` input.
