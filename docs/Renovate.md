# Renovate

Dependency updates of the organisation are opened by **Renovate**, configured by shared presets
at the root of this repository. Merging is not automated by a workflow. Dependabot
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
| Minor and patch (0.x included)     | One grouped pull request per manager (go, npm, github actions, mise)                     |
| Major                              | One grouped pull request per manager, apart from the minor/patch one, never auto-merged  |
| GitHub Actions                     | Pinned by digest (`helpers:pinGitHubActionDigests`)                                      |
| Managers                           | `gomod`, `github-actions`, `npm`, `mise` (only where the files exist), `custom.regex`    |
| Release age                        | `minimumReleaseAge: 3 days` (security preset): a release settles before it is proposed   |
| Security                           | `vulnerabilityAlerts`: one pull request per Dependabot alert, any time, no release delay, `type::security` |
| Go language version                | `go` directive in its own `go toolchain` group, apart from the library group             |
| Node (mise)                        | Even majors only (LTS)                                                                   |
| Schedule                           | Mondays before 6am (Europe/Paris)                                                        |
| Commits                            | `build(deps): Update dependency x to v1.2.3`, created through the GitHub API (signed)    |

The `security` preset (`security.json`, extended by `default`) holds every security-related setting: the
release age and `vulnerabilityAlerts`. Put new security rules there.

The `pulumi` preset adds a `pulumi sdk` group (Pulumi `sdk`/`pkg` modules, `@pulumi/pulumi` and the CLI
pinned in `.pulumi.version`) and a `pulumi provider tooling` group (`pulumi-go-provider`,
`providertest`, ...), both only for minor and patch updates from 1.0 on. It never updates the generated
SDKs (`sdk/`) nor the provider's own Go SDK required by `examples/go` through a `replace` directive, and
disables major and minor updates of Python and .NET (the floor of the generated SDKs).

Indirect Go requirements are kept enabled, as Dependabot did; the go group then carries many lookups,
disable them with a `matchDepTypes: ["indirect"]` rule if the noise is not worth it.

### Merging

No workflow merges the pull requests: they are reviewed and merged by hand (or by whatever merge bot a
repository uses). The only constraint is that the repositories allow **merge commits** only. GitHub Actions
updates touch `.github/workflows/**`; a merge of those cannot be done with the built-in `GITHUB_TOKEN`.

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

## Security

- **Alerts** (`vulnerability_alerts`) stay enabled by Terraform: they feed the Security tab (the board) and
  Renovate's security pull requests. Renovate does not create alerts, it reads them.
- **Dependabot security updates** are **off** by default (`security_features` no longer contains
  `"dependabot"`): they only open pull requests, which are Renovate's job now, and would double every
  security pull request. The alerts do not depend on them.
- Renovate opens a pull request for each alert it can fix, labelled `type::security`, without waiting for
  the 3-day release age that applies to ordinary updates.
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
- Repositories only allow **merge commits**.
