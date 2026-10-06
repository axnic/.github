# pulumi.publish - Release publish for Pulumi (stage 2 of 2)

Group `pulumi`. **Not a reusable workflow**: these jobs are generated into the release caller of a Pulumi
provider repository (`workflow_dispatch.release.yaml`, from `.github/workflows/templates/release/pulumi-publish-jobs.yaml.tftpl`),
after `prepare`; they replace [go.publish](go.publish.md) in that caller. See [Releases](Releases.md). The
provider name comes from the repository name (`pulumi-<name>`); nothing is specific to one provider.

**Why in the caller**: npm and NuGet trusted publishing match the workflow that runs the job. From a
reusable workflow of this repository the token names `axnic/.github/.github/workflows/...`, which a policy of
the provider repository cannot match (NuGet answers HTTP 401). In the caller, the token names the
repository's own `workflow_dispatch.release.yaml`.

## Purpose

Works on the tag and draft release that [release.prepare](release.prepare.md) created.

| Job        | What it does                                                                                                                                                                                  |
| ---------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `provider` | goreleaser build of the provider (`.goreleaser.yml`) without letting goreleaser publish; archives and checksums attached to the draft, a SLSA build provenance attestation for every archive, then the release is **published**. `pulumi plugin install resource <name> <version>` downloads the provider from a published release only. |
| `go-sdk`   | After `provider`: pushes the tag `sdk/go/<repository>/v<version>` on the release commit so `go get github.com/<owner>/<repository>/sdk/go/<repository>@v<version>` resolves a clean version. Fails if `sdk/go/<repository>` does not exist; a re-run is a no-op. |
| `nodejs`   | `make nodejs_sdk`, then `npm stage publish --provenance` (dist-tag `next` for a prerelease). The version is only **staged**: a maintainer approves it with 2FA (`npm stage approve <stage-id>`, or the *Staged Packages* tab on npmjs.com) before it is public. Trusted publishing (OIDC), bound to the **caller workflow file name** `workflow_dispatch.release.yaml`; `NPM_TOKEN` only as fallback. Skipped when the version is already on npm. |
| `python`   | `make python_sdk`, then twine (`--skip-existing`) with `PYPI_API_TOKEN`; skipped when the secret is missing.                                                                                    |
| `dotnet`   | `make dotnet_sdk`, then `dotnet nuget push --skip-duplicate`. Trusted publishing through `NuGet/login` when `NUGET_USER` is set, else `NUGET_API_KEY`; skipped when neither is set.              |

Each SDK job is generated only when listed in `settings.pulumi_sdks` and is its own job, so a failed registry can be re-run
alone ("Re-run failed jobs"); every step is idempotent.

Releases go public **without review**: the notes (whose summary paragraph an LLM wrote from the commit log
and the pull request descriptions) are published as is.

## Settings

| Setting (`settings`) | Default                        | Notes                                                       |
| -------------------- | ------------------------------ | ----------------------------------------------------------- |
| `pulumi_sdks`        | `["nodejs","python","dotnet"]` | The SDK jobs that are generated (`provider` and `go-sdk` always). |

## Secrets (all optional)

Read from the repository's (or the organisation's) secrets by the jobs themselves.

| Secret           | Used for                                                       |
| ---------------- | -------------------------------------------------------------- |
| `NPM_TOKEN`      | npm fallback when trusted publishing is not set up.            |
| `PYPI_API_TOKEN` | PyPI API token; without it the python SDK is skipped.          |
| `NUGET_USER`     | nuget.org user of the trusted publishing policy (OIDC).        |
| `NUGET_API_KEY`  | NuGet fallback when `NUGET_USER` is not set.                   |

## Permissions

Each job declares its own: `contents: write` (provider, go-sdk), `id-token: write` (provider, nodejs,
dotnet), `attestations: write` (provider).

## Required mise tasks

None. Makefile targets `nodejs_sdk`, `python_sdk`, `dotnet_sdk` of the Pulumi provider boilerplate (an
exception to "call `mise run`"); tools go, pulumi, pulumictl, node, yarn, python, dotnet.

## Verification

```sh
gh attestation verify <file> -R <owner>/<repo>
```

The signer is the repository's own release caller, so no `--signer-workflow` is needed.

## Known limitations

- The npm and NuGet trusted publishing policies must name the repository's own release caller
  (repository `<owner>/<repo>`, workflow file `workflow_dispatch.release.yaml`).
- npm needs npm >= 11.15.0 for `npm stage` (the job updates npm itself); the job succeeds once the version is staged, the release is complete only after the approval (the job summary says how). The "already staged" check is best effort: `npm stage list` may need a login.
- The Pulumi release is published (not left as a draft) by design, so there is no manual review of the notes.
- The upload filter covers the goreleaser artifact types Archive, Checksum, Signature, Certificate and
  SBOM only.
- The `NUGET_USER` secret is an addition to the original contract.
- PyPI uses an API token with twine, as the previous workflows did, not trusted publishing.
