# Renovate

Dependency updates of the organisation are opened by **Renovate**, configured by two shared presets
at the root of this repository, and merged by the [core.deps](core.deps.md) workflow. Dependabot
**alerts** stay on (they feed the Security tab and Renovate's security pull requests), but there is no
`dependabot.yml` and no Dependabot pull request any more.

## Using it

A repository adds a `renovate.json` (or `.github/renovate.json`):

```json
{ "extends": ["local>axnic/.github:default"] }
```

Pulumi providers use `local>axnic/.github:pulumi` instead, which extends `default`. The Renovate GitHub
App must be installed on the repository (see [Manual steps](#manual-steps)).

## What the presets do

| Rule                               | Result                                                                                   |
| ---------------------------------- | ---------------------------------------------------------------------------------------- |
| Minor and patch, versions from 1.0 | One grouped pull request per manager (go, npm, github actions, mise)                     |
| Minor of a 0.x version             | One pull request per dependency (a 0.x minor may break)                                  |
| Patch of a 0.x version             | Grouped per manager                                                                      |
| Major                              | One pull request per dependency, never grouped, never auto-merged                        |
| GitHub Actions                     | Pinned by digest (`helpers:pinGitHubActionDigests`)                                      |
| Managers                           | `gomod`, `github-actions`, `npm`, `mise` (only where the files exist), `custom.regex`    |
| Security                           | `vulnerabilityAlerts`: one pull request per Dependabot alert, any time, `type::security` |
| Schedule                           | Mondays before 6am (Europe/Paris)                                                        |
| Commits                            | `build(deps): Update dependency x to v1.2.3`, created through the GitHub API (signed)    |

The `pulumi` preset adds a `pulumi sdk` group (Pulumi `sdk`/`pkg` modules, `@pulumi/pulumi` and the CLI
pinned in `.pulumi.version`) and a `pulumi provider tooling` group (`pulumi-go-provider`,
`providertest`, ...), both only for minor and patch updates from 1.0 on. It never updates the generated
SDKs (`sdk/`) nor the provider's own Go SDK required by `examples/go` through a `replace` directive.

Go modules are `v`-prefixed, so the 0.x test is `/^[\^~=v ]*0\./` (a plain `/^0\./` never matches `v0.5.1`).
Indirect Go requirements are kept enabled, as Dependabot did; the go group then carries many lookups,
disable them with a `matchDepTypes: ["indirect"]` rule if the noise is not worth it.

### Which pull requests are merged automatically

The preset puts `<!-- axnic:auto-merge -->` in the body of the pull requests that may be merged without a
human: patches, minors from 1.0 on, and security updates. [core.deps](core.deps.md) enables auto-merge on them,
which takes effect once the required checks pass. The 0.x minors and the majors stay open, as do the
GitHub Actions updates (the built-in token cannot merge a change to `.github/workflows/**`).

### Overriding per repository

A repository's own `renovate.json` is merged after the preset. For example, rtunk's commit convention is
`^[deps]: Subject`:

```json
{
  "extends": ["local>axnic/.github:default"],
  "semanticCommits": "disabled",
  "commitMessagePrefix": "^[deps]:"
}
```

and its caller sets `deps_subject_prefix = "^[deps]"` in Terraform, as before.

## Security

- **Alerts** (`vulnerability_alerts`) stay enabled by Terraform: they feed the Security tab (the board) and
  Renovate's security pull requests. Renovate does not create alerts, it reads them.
- **Dependabot security updates** are **off** by default (`security_features` no longer contains
  `"dependabot"`): they only open pull requests, which are Renovate's job now, and would double every
  security pull request. The alerts do not depend on them.
- Renovate opens a pull request for each alert it can fix, labelled `type::security`, merged by
  [core.deps](core.deps.md) at any semver level.
- Scanning: CodeQL ([core.scan](core.scan.md)), the repository's own audit ([security.audit](security.audit.md))
  and OSV-Scanner with code-scanning upload ([security.osv](security.osv.md)).

## Manual steps

Terraform cannot do these:

1. Install the **Renovate** GitHub App on the `axnic` organisation (github.com/apps/renovate) and give it
   the repositories (all, or the chosen ones). Terraform's `github_app_installation_repository` needs a
   user token (PAT) and refuses the GitHub App token this repository authenticates with, so it is not used.
2. Check the app has read access to **Dependabot alerts** (without it `vulnerabilityAlerts` does nothing).
3. Open the onboarding pull request the app proposes, or merge the `renovate.json` of the repository.

## Branch protection

- Rulesets require signed commits: Renovate's `platformCommit` makes the app commit through the GitHub
  API, so its commits are signed ("Verified") by GitHub. Without it, no merge commit would be accepted.
- `rebaseWhen: behind-base-branch` keeps pull requests up to date, as the ruleset's strict status checks need.
- The app only needs to create branches and pull requests; it is not a ruleset bypass actor.
- Repositories only allow **merge commits**: `deps_merge_method` stays `merge`.
