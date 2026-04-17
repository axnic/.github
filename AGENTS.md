# AGENTS.md

Context and instructions for AI coding agents working in this repository.

## Overview

This is the `dot_github` repository for the **axnic** GitHub organisation. It serves two purposes:

1. **Shared GitHub Actions workflows** (`.github/workflows/`) — reusable workflows consumed by all
   repositories in the organisation.
2. **Org profile page** (`profile/README.md`) — the public profile page visible to anyone visiting
   the organisation on GitHub.

---

## Dev Environment

All dev tooling is managed via [mise](https://mise.run).

```sh
# Setup (run once after clone)
mise trust && mise install
pnpm install   # installs commitlint (dev tooling only)
```

Common commands (short aliases available — see `mise.toml`):

```sh
mise run lint           # run Trunk (single source of linting)
mise run lint:fix       # auto-fix all lint issues
```

Linter configs: `.trunk/trunk.yaml` (Trunk — manages all linters), `.commitlintrc.js`
(commit messages).

---

## CI (`.github/workflows/`)

Workflows in this repository are **shared/reusable** — they are called by other repositories in the
organisation via `workflow_call`. Keep them generic and well-documented.

---

## Commit / PR Instructions

Commit format follows **Conventional Commits with a mandatory scope**:

```text
type(scope): Subject
```

The scope is **required** and must be one of: `workflows`, `profile`, `docs`, `deps`, `tooling`.
The subject uses sentence case. The `commit-msg` git hook enforces this automatically
(via commitlint). See `.commitlintrc.js` for the full ruleset.

Run `mise run lint:commitlint` to validate a commit message manually.

### Scope reference

| Scope       | What it covers                                            |
| ----------- | --------------------------------------------------------- |
| `workflows` | Shared GitHub Actions workflows (`.github/workflows/`)    |
| `profile`   | Org profile page (`profile/README.md`)                    |
| `docs`      | Documentation (`AGENTS.md`, `*.md` at root)               |
| `deps`      | Dependency updates (actions, npm)                         |
| `tooling`   | Dev tooling (mise, trunk, commitlint, editorconfig, etc.) |

---

## Key Conventions

- **Never commit secrets.** Tokens and sensitive variables belong in repository or organisation
  secrets, not in workflow files or committed config.
- **Shared workflows must stay generic.** Avoid hardcoding org-specific values — use inputs and
  secrets to keep workflows reusable across repositories.
- **Do not hand-edit the org profile** if it is generated — check the source template instead.
