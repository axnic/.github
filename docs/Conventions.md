# Conventions

## File naming

| Kind                         | Name                            | Example                                         | Where                                   |
| ---------------------------- | ------------------------------- | ----------------------------------------------- | --------------------------------------- |
| Central (reusable) workflow  | `<group>.<action>.yaml`         | `core.qa.yaml`, `go.publish.yaml`               | `.github/workflows/` of `axnic/.github` |
| Caller workflow              | `<triggers>.<action>.yaml`      | `merge_group,pull_request,push.qa.yaml`         | `.github/workflows/` of each repository |
| E2E caller (one per version) | `<triggers>.e2e-<version>.yaml` | `merge_group,pull_request,push.e2e-v2.3.0.yaml` | same                                    |

- Central workflows are **flat** in `.github/workflows/`, prefixed by their group instead of living
  in group directories, because GitHub only loads a reusable workflow that is directly in
  `.github/workflows/` (sub-directories are not supported).
- A central workflow has no trigger other than `workflow_call`; `<group>` and `<action>` are
  lower-case letters and digits (no `-` or `_`).
- In a caller, `<triggers>` is the list of the `on:` keys of the file, **sorted alphabetically** and
  joined by commas. The caller of the release is `workflow_dispatch.release.yaml`; its name matters
  (see [Releases](Releases.md), trusted publishing).
- The `<action>` and the `name:` say what the workflow guarantees, not which tool it runs
  (`qa`, not `lint`). The caller `name:` values are the ones in the table of each page.
- `mise run ci:workflows` checks all of this on every file of `.github/workflows/`
  (`mise run ci:workflows:test` self-tests the checker). It reads the `on:` block with a line
  scanner: write `on:` as a block map, a block list, an inline list or a scalar. A flow map
  (`on: {push: ...}`) is refused.

### Documentation pages

The wiki is mirrored from `docs/` by [wiki.publish](wiki.publish.md). The action behind it copies the
directory recursively but only rewrites the links of the Markdown files at the **top level**, and
GitHub serves wiki pages by their base name. Pages are therefore **flat** in `docs/`, and a workflow
page carries the full name of its workflow: `docs/<group>.<action>.md` (page title `core.qa`). A
sub-directory per group would collide on base names (`publish` exists in both `go` and `pulumi`).

Link between pages with the relative file name, extension included: `[core.qa](core.qa.md)`. It
works when browsing the repository, and the publish step turns it into the bare wiki link.

## House style of a workflow file

Every workflow of this repository follows the same layout.

1. Line 1: `# yaml-language-server: $schema=https://json.schemastore.org/github-workflow.json`.
2. A banner between two lines of 77 `=`: `# <Title> - <short description>`, a context paragraph, the list of
   jobs. A central workflow also documents **Inputs, Secrets, Permissions, Mise tasks** and an
   **Example call** in the banner: the banner is the reference for the wiki page.
3. `permissions: {}` at the top with the comment "Minimal top-level permissions - each job declares
   what it needs.", then the permissions again on each job.
4. Each job is preceded by a `# ---...---` block (`# <job> - <what it does>`).
5. Emojis in job and step names (`⬇️ Checkout repository`, `🔧 Install tools via mise`).
6. Third-party actions pinned by **full commit SHA**, with the tag in a comment. Reuse the SHA already
   used in the other files rather than introducing a second one.
7. Mise cache key `"mise-v1-{{platform}}-{{file_hash}}"`.
8. No business logic inline: steps call `mise run <task>` (or a script of `scripts/`).
9. Everything written in a workflow (comments, names, messages) is in English.

## Callers follow `@main` on purpose

Callers reference `axnic/.github/.github/workflows/<file>@main` and carry the comment
`Intentionally not pinned: follows the latest axnic/.github (owner-controlled repo).`

- **Why**: the repository is owned by the organisation, so a fix or an improvement reaches every
  repository at once, without a pull request per repository, and a pin would have to be bumped
  everywhere on each change.
- **Trade-off**: a change merged on `main` takes effect immediately on all repositories, including a
  mistake; there is no per-repository rollback other than reverting in this repository. Merge here with
  the care of a release, and test a change on this repository first (its own callers use local
  references, see below). The scripts and the prompt used by `release.prepare` are also taken from
  `main` ([Releases](Releases.md)).
- **Consequence for signatures**: the identity that signs release artifacts is the central workflow at
  `refs/heads/main`, so verification commands pin that ref ([Releases](Releases.md)).

Third-party actions are the opposite: always pinned by SHA.

## Security rules

- **Inputs and event data reach a shell through `env:`, never by interpolation.** No `${{ inputs.x }}`
  or `${{ github.event... }}` inside a `run:` script; set an environment variable on the step and use
  `"$VAR"`. Inputs used in `with:` (not a shell) are fine.
- **Pin third-party actions by full SHA**, tag in a comment.
- **Minimal permissions**: `permissions: {}` at the top of the workflow, each job declares its own, and
  the caller grants no more than the central workflow documents.
- **`pull_request_target` never checks out or runs code from the pull request.** [oss.welcome](oss.welcome.md)
  and [pulumi.codegen](pulumi.codegen.md) only post a fixed comment; [core.review](core.review.md) only reads the
  diff through the API and must be called on `issue_comment`/`pull_request`.
- Secrets are never printed; credentials for `git push` are passed through `GIT_CONFIG_*` environment
  variables, not on the command line or persisted in the checkout (`persist-credentials: false`).
- Never commit secrets: use repository or organisation secrets.

## Commit conventions

Each repository has its own convention, enforced by its `.commitlintrc.js` (and, in
`.github-private`, by `.agents/skills/commit`). Do not assume the one of another repository.

- `axnic/.github` and `axnic/.github-private`: Conventional Commits with a **mandatory scope**,
  `type(scope): Subject` in sentence case, DCO sign-off and signed commits. Scopes of `axnic/.github`:
  `workflows`, `profile`, `docs`, `skills`, `deps`, `tooling`, `templates`.
- `rtunk` uses its own symbol convention (`type[scope]:`), which is why [core.deps](core.deps.md) takes
  a `subject-prefix` input.
- [e2e.sync](e2e.sync.md) and the Terraform `commit_message` variable must produce messages that pass the
  commitlint of the target repository.

## Self-CI of this repository

`axnic/.github` runs its own central workflows on its own pull requests, with **local references**
(`uses: ./.github/workflows/<file>`), so the version under test is the one of the commit:

| File                                        | Runs                                                                                                                         |
| ------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| `merge_group,pull_request,push.qa.yaml`     | [core.qa](core.qa.md), on every change                                                                                       |
| `push,workflow_dispatch.wiki.yaml`          | [wiki.publish](wiki.publish.md), on pushes that touch `docs/`                                                                |
| `merge_group,pull_request,push.checks.yaml` | `mise run ci:workflows`, `ci:workflows:test`, `ci:scripts` (hand-written), only when workflows, scripts or mise tasks change |

These three files are hand-written: they are the exception to "callers are generated by Terraform".
