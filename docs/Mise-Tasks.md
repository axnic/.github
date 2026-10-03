# Mise task contract

The central workflows never call a linter, compiler or test runner themselves: they run **mise
tasks that the repository defines**. A repository enables a group only if it defines the tasks the
group needs. The tasks live in the repository's mise configuration (`mise.toml`, `.mise.toml` or
`.config/mise.toml`) or as file tasks.

## The tasks

| Task                       | Role                                                                                                       | Required by                                  |
| -------------------------- | ---------------------------------------------------------------------------------------------------------- | -------------------------------------------- |
| `lint`, `lint:fix`         | Local only: `rtunk check .` and `rtunk check --fix .`. Not used by any workflow.                           | nothing (comfort)                            |
| `ci:lint`                  | Linters **specific to the repository**, never rtunk (which the workflow runs through its action). Optional. | [core.qa](core.qa.md) (job skipped if absent) |
| `ci:commitlint`            | commitlint on a range: `--from <sha> --to <sha>` or `--last`.                                              | [core.qa](core.qa.md)                        |
| `ci:build`                 | Check that the project builds.                                                                             | [go.test](go.test.md)                        |
| `ci:test`                  | Run the tests (and write the coverage profile).                                                            | [go.test](go.test.md)                        |
| `ci:coverage`              | Enforce the coverage floor. Runs **after** `ci:test` in the same job, so it may read the profile `ci:test` wrote. | [go.test](go.test.md)                 |
| `security:audit`           | Audit the repository's dependencies, whatever the ecosystems (Go, Node.js, ...).                           | [security.audit](security.audit.md)          |
| `ci:e2e`                   | Run the E2E suite against one version, read from the environment variable `E2E_VERSION`.                   | [e2e.run](e2e.run.md)                        |
| `ci:e2e:versions`          | Print the versions to cover, one per line, **on stdout only**. Each line is also the exact `E2E_VERSION` and the suffix of the caller file name. | [e2e.sync](e2e.sync.md) |
| `ci`                       | Local aggregate gate (lint, build, tests). Run by `release.prepare` on the commit to release.              | [release.prepare](release.prepare.md)        |

Tools come from mise: `"github:axnic/rtunk" = "latest"` for rtunk (there is no `trunk`), its configuration
is `.rtunk/rtunk.yaml`. The `release.prepare` and publish workflows also rely on files other than tasks:
`.goreleaser.yml` for [go.publish](go.publish.md) and the Makefile targets of the Pulumi boilerplate for
[pulumi.publish](pulumi.publish.md).

## Which group needs what

| Group      | Required tasks                                                     |
| ---------- | ------------------------------------------------------------------ |
| `core`     | `ci:commitlint` (`ci:lint` optional)                               |
| `go`       | `ci:build`, `ci:test`, `ci:coverage`                               |
| `pulumi`   | the same as `go` (the group includes it)                           |
| `release`  | `ci`                                                               |
| `security` | `security:audit`                                                   |
| `e2e`      | `ci:e2e` and `ci:e2e:versions`                                     |
| `issues`, `oss`, `wiki` | none                                                  |

## Requirements for each task

- **Be quiet on stdout when asked to**: `ci:e2e:versions` must print only the versions on stdout
  (diagnostics go to stderr).
- **`ci:commitlint` must not read stdin without a range.** commitlint with no range waits on stdin;
  fail fast with a usage message instead.
- **`ci:coverage` after `ci:test`.** Do not make `ci:coverage` depend on `ci:test` (the workflow would run
  the tests twice); read the profile that `ci:test` wrote, and produce it only if it is absent, so
  the task also works alone.
- **`ci` is an ordered chain, not a parallel dependency list.** Use an explicit sequence when a task
  reads the output of the previous one.
- `ci:lint` must not run rtunk: rtunk already runs in its own job of `core.qa`.

## Examples

### A Go repository

Taken from the shape of the `rtunk` repository.

```toml
[tools]
"github:axnic/rtunk" = "latest"
"npm:@commitlint/cli" = "latest"

[tasks.lint]
description = "Lint the whole repository with rtunk"
run = "rtunk check ."

[tasks."lint:fix"]
description = "Lint the whole repository with rtunk and apply the fixes"
run = "rtunk check --fix ."

[tasks."ci:commitlint"]
description = "Validate commit messages (usage: mise run ci:commitlint -- --from <sha> --to <sha> | --last)"
run = "commitlint --verbose"

[tasks."ci:build"]
description = "Build the binary"
run = "go build -o app ./cmd/app"

[tasks."ci:test"]
description = "Run the unit tests with the race detector and a coverage profile"
run = "go test -race -covermode=atomic -coverprofile=coverage.txt ./..."

[tasks."ci:coverage"]
description = "Fail if total statement coverage is below the floor"
env = { COVERAGE_FLOOR = "80" }
run = '''
[ -f coverage.txt ] || go test -race -covermode=atomic -coverprofile=coverage.txt ./...
total=$(go tool cover -func=coverage.txt | tail -1 | awk '{print $NF}' | tr -d '%')
echo "Total statement coverage: ${total}%"
awk -v total="$total" -v floor="$COVERAGE_FLOOR" 'BEGIN { if (total + 0 < floor + 0) { print "coverage " total "% is below the " floor "% floor"; exit 1 } }'
'''

[tasks."security:audit"]
description = "Scan Go dependencies for known vulnerabilities"
run = "govulncheck ./..."

[tasks.ci]
description = "Local gate run before a release"
# Explicit order, not `depends` (parallel): ci:test writes the profile that ci:coverage reads.
run = [{ task = "ci:build" }, { task = "ci:test" }, { task = "ci:coverage" }]
```

### A Pulumi provider

Taken from the shape of the `pulumi-garage` repository: the tasks wrap the Makefile, the audit covers
the Go module and the generated Node.js SDK, and the E2E tasks are specific to the provider.

```toml
[tasks."ci:build"]
description = "Build the provider binary"
run = "make provider"

[tasks."ci:test"]
description = "Run the provider unit tests (writes provider/coverage.txt)"
run = "make test"

[tasks."ci:coverage"]
description = "Fail if total statement coverage is below the floor"
env = { COVERAGE_FLOOR = "60" }
run = '''
total=$(go tool cover -func=provider/coverage.txt | tail -1 | awk '{print $NF}' | tr -d '%')
echo "Total statement coverage: ${total}%"
awk -v total="$total" -v floor="$COVERAGE_FLOOR" 'BEGIN { if (total + 0 < floor + 0) { print "coverage " total "% is below the " floor "% floor"; exit 1 } }'
'''

[tasks."security:audit"]
description = "Audit the dependencies (Go module and nodejs SDK)"
run = '''
set -e
govulncheck ./...
cd sdk/nodejs && yarn audit --groups dependencies
'''

# E2E_VERSION is the tag of the service under test (e.g. v2.3.0).
[tasks."ci:e2e"]
description = "Run the E2E suite (usage: E2E_VERSION=v2.3.0 mise run ci:e2e)"
run = '''
: "${E2E_VERSION:?E2E_VERSION is required (e.g. v2.3.0)}"
export GARAGE_VERSION="$E2E_VERSION"
make test_e2e
'''

[tasks."ci:e2e:versions"]
description = "Print one version per line"
run = '''
set -euo pipefail
curl -sfL "https://git.deuxfleurs.fr/api/v1/repos/Deuxfleurs/garage/releases" \
  | jq -r '.[] | select(.prerelease == false) | .tag_name' \
  | grep -E '^v2\.[0-9]+\.[0-9]+$' \
  | sed -E 's/^(v2\.[0-9]+)\..*/\1.0/' | sort -uV
'''

[tasks.ci]
description = "Local CI quality gate: lint, build, tests, coverage"
depends = ["lint", "ci:build", "ci:test"]
run = "mise run ci:coverage"
```

`lint` and `ci:commitlint` are as in the Go example (`pulumi-garage` additionally guards `ci:commitlint`
against a missing range).

### A minimal repository

A repository with only the `core` group needs a single task, plus `lint` for local use. Taken from the
shape of `medieval-claude`.

```toml
[tools]
node = "lts"
"github:axnic/rtunk" = "latest"
"npm:@commitlint/cli" = "latest"

[tasks.lint]
description = "Lint the whole repository with rtunk"
run = "rtunk check ."

[tasks."ci:commitlint"]
description = "Validate commit messages (usage: mise run ci:commitlint -- --from <sha> --to <sha> | --last)"
run = "commitlint --verbose"
```

## How Terraform checks the tasks

The `workflows` module (`terraform/modules/workflows`) refuses to plan a group whose tasks are missing. It
reads the repository's **default branch** (not a pull request). It decodes `mise.toml`, `.mise.toml`
and `.config/mise.toml` with a TOML provider and collects the keys of their `tasks` table, and it
recognises file tasks in the git tree under `mise-tasks/`, `.mise-tasks/`, `mise/tasks/`,
`.mise/tasks/` and `.config/mise/tasks/` (`.mise/tasks/ci/test` is the task `ci:test`). A missing task
fails the plan with `repo <name>: mise task <task> is missing, required by group <group>`.

Consequences:

- Merge the pull request that adds the mise tasks **before** applying Terraform.
- Other mise configuration files (for example `mise.test.toml`) are not read.
- The check is about existence, not behaviour: the first run of a workflow is the real test.
