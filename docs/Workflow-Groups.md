# Workflow groups

A repository enables **groups** of workflows in Terraform ([Adding-A-Repo](Adding-A-Repo.md)); each group
generates caller workflows in the repository ([Central-CI](Central-CI.md)). This page tells the owner of a
repository, for each group, which callers appear, which [mise tasks](Mise-Tasks.md) the repository must
define, and exactly what each task must do. The reference for the contract that applies to every task
(quiet stdout, no stdin, ordering) is [Mise-Tasks](Mise-Tasks.md); the long examples stay there.

Source of truth: `terraform/modules/workflows` (`catalog.tf`, `main.tf`, `variables.tf`), the caller
templates in `.github/workflows/templates/` and the banner of each reusable workflow.

## Summary

| Group                      | Callers (file names)                                                                                                       | Required tasks                  |
| -------------------------- | -------------------------------------------------------------------------------------------------------------------------- | ------------------------------- |
| `core`                     | `merge_group,pull_request,push.qa.yaml`, `issue_comment,pull_request.review.yaml`, `pull_request,push,schedule.scan.yaml` | `ci:commitlint` (`ci:lint` optional) |
| `issues`                   | `schedule,workflow_dispatch.stale.yaml`                                                                                    | none                            |
| `go`                       | `pull_request,push.test.yaml`                                                                                              | `ci:build`, `ci:test`, `ci:coverage` |
| `pulumi`                   | `pull_request_target.codegen.yaml` plus everything from `go`                                                               | the tasks of `go`               |
| `security`                 | `schedule,workflow_dispatch.audit.yaml`, `pull_request,push,schedule.osv.yaml`                                             | `security:audit`                |
| `oss`                      | `schedule,workflow_dispatch.scorecard.yaml`, `pull_request_target.welcome.yaml`                                            | none                            |
| `e2e`                      | `schedule,workflow_dispatch.e2e-sync.yaml`, then one `merge_group,pull_request,push.e2e-<version>.yaml` per version        | `ci:e2e`, `ci:e2e:versions`     |
| `wiki`                     | `push,workflow_dispatch.wiki.yaml`                                                                                         | none                            |
| `release:go`               | `workflow_dispatch.release.yaml` (`prepare` + `publish`)                                                                   | `ci`                            |
| `release:npm`           | `workflow_dispatch.release.yaml` (`prepare` + `npm`)                                                                       | `ci`, `ci:build`                |
| `release:pulumi`           | `workflow_dispatch.release.yaml` (`prepare` + Pulumi publish jobs)                                                         | `ci`                            |
| `release:argocd-extension` | `workflow_dispatch.release.yaml` (`prepare` + `extension`)                                                                 | `ci`, `ci:build`                |

The four `release:*` groups all pass the repository's `commit_format` to `prepare` (`commit-format`), see [Releases](Releases.md#commit-formats-and-the-bump).

Caller files are named `<sorted triggers>.<action>.yaml`. They are managed by Terraform: never edit them
by hand. A group is refused at plan time if a required task is missing (see
[how Terraform checks the tasks](Mise-Tasks.md#how-terraform-checks-the-tasks)).

**Tests today.** Only the `go` group (hence `pulumi`) runs tests on pull requests (`ci:test`, then
`ci:coverage`). **No group runs tests for a Node.js repository.** A Node.js repository gets its lint and
commit checks from `core`, and its build and whatever its own `ci` task contains from `release:npm` or
`release:argocd-extension`, at release time only. If the tests matter, put them in `ci`: that is the only
place a Node.js repository's tests run today.

## core

Callers:

| File                                      | Workflow                       | Role                                                                |
| ----------------------------------------- | ------------------------------ | ------------------------------------------------------------------- |
| `merge_group,pull_request,push.qa.yaml`   | [core.qa](core.qa.md)          | repository linters, rtunk, commit messages                          |
| `pull_request,push,schedule.scan.yaml`    | [core.scan](core.scan.md)      | CodeQL (daily schedule `0 6 * * *`)                                 |
| `issue_comment,pull_request.review.yaml`  | [core.review](core.review.md)  | PR-Agent review on demand; only generated with a PR-Agent budget    |

Tasks:

- `ci:commitlint` (required). Validates commit messages on a range given after `--`: `--from <sha> --to <sha>`
  or `--last`. The workflow passes `--last` on push, and `--from/--to` for the commits of a pull request.
  With no range it must **fail fast with a usage message**, never read stdin (commitlint would hang).
  Dependabot pull requests are skipped by the workflow. The commitlint configuration must enforce the
  repository's `commit_format` (default `gitsym`): the sync commits, the e2e subject and the release
  notes all assume it, and Terraform cannot set it ([Commit-Formats](Commit-Formats.md),
  [Mise-Tasks](Mise-Tasks.md#commit-format-and-ci-commitlint)).
- `ci:lint` (optional, the job is skipped if absent). Linters specific to the repository. It must **not** run
  rtunk: rtunk has its own job in `core.qa`, configured by `.rtunk/rtunk.yaml`.

```toml
[tasks."ci:commitlint"]
description = "Validate commit messages (usage: mise run ci:commitlint -- --from <sha> --to <sha> | --last)"
run = "commitlint --verbose"
```

**Settings** (`workflow_params`): `scan_cron` (default `0 6 * * *`), `scan_languages` (CodeQL languages,
central default `["go"]`: set it for any other language, e.g. `["javascript-typescript"]`),
`review_model`, `review_fallback_model`.

Prerequisites and constraints:

- `.rtunk/rtunk.yaml` in the repository.
- `review` needs a **PR-Agent budget** (`pr_agent = { monthly_budget_usd = N }`, which creates the
  OpenRouter key): without it the caller is not generated, and requesting `core.review` explicitly is a plan
  error. The budget is the owner's decision. The commenters allowed to run commands come from the
  repository variable `PR_AGENT_ALLOWED_USERS` (JSON list of logins); while unset, nothing runs.
- `scan` and `osv` do not run on Dependabot and fork pull requests (their token cannot write code scanning).

## issues

**Caller**: `schedule,workflow_dispatch.stale.yaml` ([issues.stale](issues.stale.md)), cron `30 1 * * *`.

**Tasks**: none.

**Settings**: `stale_cron`, `stale_days` (central default 60), `stale_close_days` (central default 14).

Prerequisites and constraints:

- The repository feature `issues` must be enabled (`features`); otherwise the plan is refused.
- Opt-in on purpose: the workflow really labels and closes issues.

## go

**Caller**: `pull_request,push.test.yaml` ([go.test](go.test.md)). The `on:` has a `paths:` filter: a change
outside `settings.go_paths` (and the caller itself) does not run it.

**Tasks** (all three required; the workflow runs them in this order, `build` in its own job on Linux, then
`ci:test` and `ci:coverage` in the same job on each OS):

| Task          | Must do                                                                                                                                              |
| ------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------- |
| `ci:build`    | Check that the project builds. Fail on any build error.                                                                                              |
| `ci:test`     | Run the tests and **write the coverage profile** (for example `coverage.txt`). Fail if a test fails.                                                  |
| `ci:coverage` | Enforce the coverage floor by **reading the profile `ci:test` wrote**; produce it only if absent so the task also works alone. Fail below the floor. |

`ci:coverage` must not `depends` on `ci:test`: the workflow already ran it, the tests would run twice. A
complete Go example is in [Mise-Tasks](Mise-Tasks.md#a-go-repository).

**Settings**: `go_paths` (default `["**.go", "go.mod", "go.sum"]`, path filter of the caller), `go_os`
(input `os`, central default `["ubuntu-latest","macos-latest"]`). Tasks must therefore work on both Linux
and macOS runners unless `go_os` narrows it.

**Prerequisites**: tools (Go and anything the tasks call) installed through mise.

## pulumi

**Callers**: `pull_request_target.codegen.yaml` ([pulumi.codegen](pulumi.codegen.md)) **plus all the `go`
callers** (the group includes `go`).

**Tasks**: those of [go](#go), with the Makefile of the provider behind them (`make provider`,
`make test`, a coverage check on `provider/coverage.txt`); see
[A Pulumi provider](Mise-Tasks.md#a-pulumi-provider). `codegen` itself needs no task: it never checks out
the pull request, and only comments on fork pull requests that edit `sdk/` without a `schema.json`.

**Prerequisites**: a Pulumi provider layout (`sdk/`, `provider/cmd/<binary>/schema.json`, `make codegen`).

**Constraints**: the group alone does not publish; add `release:pulumi` for the release.

## security

Callers:

| File                                       | Workflow                              | Role                                                                          |
| ------------------------------------------ | ------------------------------------- | ----------------------------------------------------------------------------- |
| `schedule,workflow_dispatch.audit.yaml`    | [security.audit](security.audit.md)   | runs the repository's audit task (daily `0 6 * * *`)                          |
| `pull_request,push,schedule.osv.yaml`      | [security.osv](security.osv.md)       | OSV-Scanner on the lockfiles, SARIF in the Security tab (Monday `30 5 * * 1`) |

**Tasks**: `security:audit` (required). Audit the dependencies of the repository, **whatever the
ecosystems** (Go, Node.js, ...): chain all the audits in one task and make it exit non-zero on a finding.
Use `set -e` when it chains several commands. Output goes to the job log. `osv` needs no task.

```toml
[tasks."security:audit"]
description = "Audit the dependencies"
run = '''
set -e
govulncheck ./...
yarn audit --groups dependencies
'''
```

**Settings**: `audit_cron`, `osv_cron`.

## oss

**Callers**: `schedule,workflow_dispatch.scorecard.yaml` ([oss.scorecard](oss.scorecard.md), Monday
`0 5 * * 1`) and `pull_request_target.welcome.yaml` ([oss.welcome](oss.welcome.md)).

**Tasks**: none.

**Settings**: `scorecard_cron`, `welcome_message` (central default text when unset).

**Constraints**: opt-in, for public repositories (Scorecard publishes its result). `welcome` only comments
on fork pull requests.

## e2e

**Callers**: `schedule,workflow_dispatch.e2e-sync.yaml` ([e2e.sync](e2e.sync.md), Monday `0 3 * * 1`). The
sync then opens a pull request that creates one `merge_group,pull_request,push.e2e-<version>.yaml` caller
per version ([e2e.run](e2e.run.md)), plus a badge row in the README.

**Tasks** (both required)

| Task              | Must do                                                                                                                                                                                                |
| ----------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `ci:e2e:versions` | Print the versions to cover, **one per line, on stdout only** (diagnostics on stderr). Each line is the exact `E2E_VERSION` and the suffix of the caller file name, so it must match `^[A-Za-z0-9._-]+$`. |
| `ci:e2e`          | Run the E2E suite against **one** version, read from the environment variable `E2E_VERSION`. Fail fast if it is unset. How the service is started is the task's business.                                |

```toml
[tasks."ci:e2e"]
description = "Run the E2E suite (usage: E2E_VERSION=v2.3.0 mise run ci:e2e)"
run = '''
: "${E2E_VERSION:?E2E_VERSION is required}"
make test_e2e
'''
```

**Settings**: `e2e_sync_cron`, `e2e_readme_path` (default `README.md`), `e2e_commit_subject` (central
default derived from `commit_format`: `=[ci]: Sync E2E callers`, `ci(ci): Sync E2E callers` or `:construction_worker: (ci): Sync E2E callers`; it must satisfy the repository's commitlint).

**Prerequisites**: an e2e badge table in the README (without it the README is left alone), the repository
setting "Allow GitHub Actions to create and approve pull requests", and the `axnic-bot` GitHub App
([CI-GitHub-App](CI-GitHub-App.md)): `GITHUB_TOKEN` can never push files under `.github/workflows/`.

## wiki

**Caller**: `push,workflow_dispatch.wiki.yaml` ([wiki.publish](wiki.publish.md)), on push to the default
branch filtered on the docs directory, serialized by a `concurrency` group.

**Tasks**: none.

**Settings**: `wiki_docs_dir` (default `docs`; also the push path filter).

**Prerequisites**: the `wiki` feature enabled and the wiki initialized (one page created by hand). The
directory is mirrored as is: docs are flat.

## Release groups

All `release:*` groups generate the **same single caller**, `workflow_dispatch.release.yaml`, whose first
job `prepare` ([release.prepare](release.prepare.md)) is common; each group adds its own publish part. The
file name matters: npm and NuGet trusted publishing are bound to it, do not rename it. See
[Releases](Releases.md) for the two-stage process and recovery.

**Task `ci`** (required by every release group). It is run by `prepare` on the commit about to be
released: it is the full local gate (lint, build, tests). It must be an **ordered chain**, not a parallel
`depends` list, when a step reads the output of the previous one (for example `ci:coverage` after
`ci:test`). It must exit non-zero on any failure, as nothing is tagged afterwards.

```toml
[tasks.ci]
description = "Local gate run before a release"
run = [{ task = "ci:build" }, { task = "ci:test" }, { task = "ci:coverage" }]
```

The dispatch takes `bump` (`auto`, `patch`, `minor`, `major`, or `manual`) and `version` (only with
`manual`), and an optional `notes` override. `OPENROUTER_API_KEY` is optional (without it the notes stay
deterministic).

### release:go

- **Publish part**: job `publish`, the reusable [go.publish](go.publish.md); artifacts are attached to the
  **draft** release, which stays a manual step to publish.
- **Tasks**: `ci` only.
- **Prerequisites**: `.goreleaser.yml` with `sboms` (syft) and `signs` (cosign, keyless) sections: the job
  fails when no SBOM or no signature is produced. `go`, `cosign` and `syft` come from the mise tools.

### release:npm

- **Publish part**: job `npm`, generated into the caller. Sets the package version from the tag
  (`npm version`, `package.json` is not bumped by the release), runs `mise run ci:build`, then
  `npm stage publish --provenance` (dist-tag `next` for a prerelease, `latest` otherwise). The version is
  only **staged**: a maintainer approves it with 2FA (`npm stage approve <stage-id>` or the *Staged
  Packages* tab on npmjs.com).
- **Settings**: `npm_dir` (default `.`): directory of the `package.json` to version and publish, relative
  to the repository root, e.g. `workflow_params = { npm_dir = "packages/commitlint" }` for a monorepo.
- **Tasks**: `ci` and `ci:build`. `ci:build` runs at the repository root and must produce the package in a
  state `npm stage publish` can publish from `npm_dir` (`npm version` and `npm stage publish` run there,
  after the version is set).
- **Prerequisites**: npm **trusted publishing** configured on npmjs.com for the repository and the workflow
  file `workflow_dispatch.release.yaml`, or the secret `NPM_TOKEN` as a fallback. A version already on npm
  cannot be reused and is skipped.
- **Tests**: none beyond what `ci` runs (see [Summary](#summary)).

### release:pulumi

- **Publish part**: jobs generated into the caller, replacing `go.publish`: `provider` (goreleaser build,
  attestation, the release is **published**, not left as a draft), `go-sdk` (pushes the tag
  `sdk/go/<repository>/v<version>`), then one job per SDK in `pulumi_sdks`: `nodejs`, `python`, `dotnet`.
  Details: [pulumi.publish](pulumi.publish.md).
- **Tasks**: `ci` only. The publish jobs call **Makefile targets** instead of mise tasks: `make nodejs_sdk`,
  `make python_sdk`, `make dotnet_sdk` (Pulumi provider boilerplate), and goreleaser with `.goreleaser.yml`.
- **Settings**: `pulumi_sdks` (default `["nodejs","python","dotnet"]`).
- **Secrets** (all optional): `NPM_TOKEN` (fallback to trusted publishing), `PYPI_API_TOKEN` (without it
  the python SDK is skipped), `NUGET_USER` (trusted publishing) or `NUGET_API_KEY` (without either, the
  dotnet SDK is skipped).
- **Prerequisites**: the directory `sdk/go/<repository>` (the `go-sdk` job fails without it) and the
  trusted publishing policies naming the repository and `workflow_dispatch.release.yaml`.
- **Constraint**: `release:pulumi` **cannot be combined with `release:go` or `release:npm`** (plan
  error): it already builds the provider and publishes the npm SDK.

### release:argocd-extension

- **Publish part**: job `extension`, generated into the caller. Runs `mise run ci:build` (with the
  environment variable `VERSION` set to the version without `v`), checks that the bundle exists, writes
  `<bundle name>_checksums.txt` (bare file name, as `argocd-extension-installer` expects), attests the
  build provenance, and attaches both to the **draft** release.
- **Tasks**: `ci` and `ci:build`. `ci:build` **must produce the bundle at `extension_archive`**; the job
  fails with an error otherwise.
- **Settings**: `extension_archive` (default `dist/extension.tar`; letters, digits, `.`, `_`, `/`, `-`, no
  leading `/`). The checksum file name is derived from it by stripping `.tar`, so use a `.tar` archive.

Illustrative `ci:build` (the build commands are the repository's own):

```toml
[tasks."ci:build"]
description = "Build the extension bundle (writes dist/extension.tar)"
run = '''
yarn install --immutable
yarn build
mkdir -p dist
tar -cf dist/extension.tar -C build .
'''
```

### Combining release groups

| Combination                                       | Allowed                                                         |
| ------------------------------------------------- | --------------------------------------------------------------- |
| `release:npm` + `release:argocd-extension`     | Yes: one caller with `prepare`, `npm` and `extension`           |
| `release:pulumi` + `release:go` or `release:npm` | No (plan error)                                               |
| `release:go` + `release:argocd-extension`         | Not forbidden by a validation; both jobs attach to the same draft |
