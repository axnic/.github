# Commit formats

Each managed repository declares one commit format with the Terraform setting `commit_format`
([Adding-A-Repo](Adding-A-Repo.md)). Terraform and the central workflows read it; the repository's own
commitlint must enforce the same one, since Terraform cannot set it ([Mise-Tasks](Mise-Tasks.md#commit-format-and-ci-commitlint)).

| Format   | Value on the setting | Header                          | Example                                  |
| -------- | -------------------- | ------------------------------- | ---------------------------------------- |
| gitsym   | `gitsym` (default)   | `type[scope]: Subject`          | `+[api]: Add pagination`                 |
| Conventional Commits | `cc`     | `type(scope)!: Subject`         | `feat(api): Add pagination`              |
| Gitmoji  | `gitmoji`            | `:code: (scope)!: Subject`      | `:sparkles: (api): Add pagination`       |

- **gitsym** ([axnic/gitsym](https://github.com/axnic/gitsym)): the type is one ASCII symbol, 12 types, the
  scope is optional (several scopes: `[api,auth]`). Three breaking variants: `+!`, `~!`, `-!`.
- **cc**: the Conventional Commits types, the scope is optional, `!` after the scope marks a breaking change.
- **gitmoji**: a gitmoji code, then the optional scope in parentheses; `:boom:` or `!` marks a breaking change.

In every format a `BREAKING CHANGE:` footer is a breaking change, and the subject is in sentence case.

## Type correspondence

Summarised from the gitsym README, where the equivalents are a migration aid, not a strict mapping.
The gitmoji column gives the usual code for the symbol; the full code-to-symbol table is
`scripts/gitmoji-types.json` (a code missing from it counts as `*`).

| gitsym | Meaning                                  | cc                                          | gitmoji (examples)                |
| ------ | ---------------------------------------- | ------------------------------------------- | --------------------------------- |
| `+`    | New feature, service, resource           | `feat`                                      | `:sparkles:`                      |
| `-`    | Remove code, file, service               | `chore` (removal)                           | `:fire:`                          |
| `~`    | Perf, config, improvement (not a bug)    | `perf`, `feat`                              | `:zap:`, `:wrench:`               |
| `!`    | Fix a bug                                | `fix`                                       | `:bug:`                           |
| `=`    | Refactor, style, tests, CI               | `refactor`, `style`, `test`, `ci`, `build`  | `:recycle:`, `:construction_worker:` |
| `^`    | Dependency bump                          | `build(deps)`, `chore(deps)`                | `:arrow_up:`                      |
| `>`    | Move or rename                           | `refactor`                                  | `:truck:`                         |
| `<`    | Revert                                   | `revert`                                    | `:rewind:`                        |
| `@`    | Documentation                            | `docs`                                      | `:memo:`                          |
| `$`    | Security                                 | `fix` (security)                            | `:lock:`                          |
| `?`    | Experiment                               | none (closest `chore`)                      | `:alembic:`                       |
| `*`    | Anything else                            | `chore`                                     | `:construction:`                  |
| `+!` `~!` `-!` | Breaking add, improve, remove    | `feat!`, `perf!`, `fix!`, `chore!`, ...     | `:boom:`                          |

## Where the format matters

| What                                   | Effect of `commit_format`                                                                  |
| -------------------------------------- | ------------------------------------------------------------------------------------------ |
| Caller commits written by Terraform    | `=[ci]: Sync %s from axnic/.github` / `ci(ci): Sync %s from axnic/.github` / `:construction_worker: (ci): Sync %s from axnic/.github`. `workflow_commit_message` overrides it. |
| [e2e.sync](e2e.sync.md) commit subject | `=[ci]: Sync E2E callers` / `ci(ci): Sync E2E callers` / `:construction_worker: (ci): Sync E2E callers`. The setting `e2e_commit_subject` overrides it. |
| [release.prepare](release.prepare.md)  | Input `commit-format`: how `bump: auto` computes the version and how the notes group commits ([Releases](Releases.md#commit-formats-and-the-bump)). |
| The repository's commitlint            | **Not set by Terraform**: configure it to the same format ([Mise-Tasks](Mise-Tasks.md#commit-format-and-ci-commitlint)). |
