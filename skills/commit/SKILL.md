---
name: commit
description: >
  Generates gitsym commit messages for this project. Use when asked to
  commit changes, write a commit message, stage files, or prepare a commit.
  Enforces the gitsym format with mandatory scope, WHY-focused body,
  Co-authored-by transparency trailer, DCO sign-off, and cryptographic signature.
compatibility: Requires git
allowed-tools: Bash(git:*)
---

# Commit Skill

This project follows [gitsym](https://github.com/axnic/gitsym): the type is one ASCII symbol.

## Commit format

```text
<type>[<scope>]: <Subject starting with uppercase>

<body — one or more paragraphs explaining WHY>

<footer — Co-authored-by and Signed-off-by trailers>
```

## Types

| Type | When to use                                              |
| ---- | -------------------------------------------------------- |
| `+`  | New feature, resource or file                            |
| `-`  | Remove code, file or feature                             |
| `~`  | Improvement of working behavior: performance, config     |
| `!`  | Fix a bug                                                |
| `=`  | No behavior change: refactor, style, tests, CI           |
| `^`  | Dependency bump                                          |
| `>`  | Move or rename                                           |
| `<`  | Revert a previous commit                                 |
| `@`  | Documentation only                                       |
| `$`  | Security                                                 |
| `?`  | Experiment                                               |
| `*`  | Anything else                                            |

Breaking changes: `+!`, `~!` or `-!`. The full table is in the
[specification](https://github.com/axnic/gitsym/blob/main/docs/specification.md).

## Scopes

| Scope       | What it covers                                                                              |
| ----------- | ------------------------------------------------------------------------------------------- |
| `workflows` | Shared GitHub Actions workflows (`.github/workflows/`)                                      |
| `terraform` | Terraform configuration and caller templates (`terraform/`, `.github/workflows/templates/`) |
| `profile`   | Org profile page (`README.md`, generated)                                                   |
| `docs`      | Documentation (`docs/`, `AGENTS.md`, `*.md` at root)                                        |
| `skills`    | Agent skills (`skills/`)                                                                    |
| `deps`      | Dependency updates (actions, npm)                                                           |
| `tooling`   | Dev tooling (mise, rtunk, commitlint, editorconfig, etc.)                                   |

## The body — WHY, not WHAT

The body is **required** and must explain:

- **Why** this change is being made (the motivation, the problem it solves)
- **What alternatives were considered** and why they were rejected
- **Trade-offs or limitations** the reviewer should be aware of

The body must **never** describe what the diff already shows. The diff shows
_what_ changed; the body tells the story _behind_ the change.

For good/bad examples and a full commit sample, read `references/body-guide.md`.

## Gathering context before writing

If the context needed to write a meaningful body is missing:

1. **Ask the user** — one focused question: "What problem does this change
   solve?" or "Why was this approach chosen over X?".
2. **Infer from the diff** — run `git diff --staged` (or `git diff HEAD` for
   already-committed changes) and `git log --oneline -10` to read the
   surrounding history. Flag any assumptions with "Based on the diff, this
   appears to …".

Never fabricate motivation. If context cannot be inferred, ask.

## Co-authored-by — required

**Every AI-assisted commit must include a `Co-authored-by` trailer.**

| Tool                           | Trailer                                                                |
| ------------------------------ | ---------------------------------------------------------------------- |
| GitHub Copilot (any model)     | `Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>` |
| Claude (Anthropic, direct)     | `Co-authored-by: Claude Sonnet 4.6 <claude@anthropic.com>`             |
| GPT / ChatGPT (OpenAI, direct) | `Co-authored-by: Codex <chatgpt@openai.com>`                           |

If the user declines the trailer: acknowledge, explain the project convention,
and still propose the full message with the trailer. The final decision is
theirs, but the policy must be surfaced — omitting it silently is not acceptable.

## Sign-off and cryptographic signature — both required

```sh
git commit -s -S -m "<message>"
# -s  adds Signed-off-by (DCO)
# -S  adds cryptographic signature (SSH/GPG)
```

For GPG vs SSH setup details, read `references/signing.md`.
