# pulumi.publish - Release publish for Pulumi (stage 2 of 2)

Group `pulumi`. Central workflow: `.github/workflows/pulumi.publish.yaml`. Second job of the release
caller of a Pulumi provider repository (`needs: prepare`); it replaces [go.publish](go.publish.md) in
that caller and takes `sdks` instead of `prerelease`. See [Releases](Releases.md). The provider name
comes from the repository name (`pulumi-<name>`); nothing is specific to one provider.

## Purpose

Works on the tag and draft release that [release.prepare](release.prepare.md) created.

| Job        | What it does                                                                                                                                                                                  |
| ---------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `provider` | goreleaser build of the provider (`.goreleaser.yml`) without letting goreleaser publish; archives and checksums attached to the draft, a SLSA build provenance attestation for every archive, then the release is **published**. `pulumi plugin install resource <name> <version>` downloads the provider from a published release only. |
| `go-sdk`   | After `provider`: pushes the tag `sdk/go/<repository>/v<version>` on the release commit so `go get github.com/<owner>/<repository>/sdk/go/<repository>@v<version>` resolves a clean version. Fails if `sdk/go/<repository>` does not exist; a re-run is a no-op. |
| `nodejs`   | `make nodejs_sdk`, then `npm publish --provenance` (dist-tag `next` for a prerelease). Trusted publishing (OIDC), bound to the **caller workflow file name** `workflow_dispatch.release.yaml`; `NPM_TOKEN` only as fallback. Skipped when the version is already on npm. |
| `python`   | `make python_sdk`, then twine (`--skip-existing`) with `PYPI_API_TOKEN`; skipped when the secret is missing.                                                                                    |
| `dotnet`   | `make dotnet_sdk`, then `dotnet nuget push --skip-duplicate`. Trusted publishing through `NuGet/login` when `NUGET_USER` is set, else `NUGET_API_KEY`; skipped when neither is set.              |

Each SDK job runs only when listed in `sdks` and is its own job, so a failed registry can be re-run
alone ("Re-run failed jobs"); every step is idempotent.

Releases go public **without review**: the notes (whose summary paragraph an LLM wrote from the commit log
and the pull request descriptions) are published as is.

## When it runs

As the `publish` job of the release caller `workflow_dispatch.release.yaml`.

## Inputs

| Input     | Type   | Default                           | Notes                                              |
| --------- | ------ | --------------------------------- | -------------------------------------------------- |
| `tag`     | string | -                                 | **Required.** The tag pushed by `release.prepare`.  |
| `version` | string | -                                 | **Required.** The version without `v` (`PROVIDER_VERSION` of the Makefile). |
| `sdks`    | string | `["nodejs","python","dotnet"]`    | JSON array of the SDKs to publish.                  |

## Secrets (all optional)

| Secret           | Used for                                                       |
| ---------------- | -------------------------------------------------------------- |
| `NPM_TOKEN`      | npm fallback when trusted publishing is not set up.            |
| `PYPI_API_TOKEN` | PyPI API token; without it the python SDK is skipped.          |
| `NUGET_USER`     | nuget.org user of the trusted publishing policy (OIDC).        |
| `NUGET_API_KEY`  | NuGet fallback when `NUGET_USER` is not set.                   |

## Permissions (granted by the caller)

`contents: write`, `id-token: write`, `attestations: write`

## Required mise tasks

None. Makefile targets `nodejs_sdk`, `python_sdk`, `dotnet_sdk` of the Pulumi provider boilerplate (an
exception to "call `mise run`"); tools go, pulumi, pulumictl, node, yarn, python, dotnet.

## Verification

```sh
gh attestation verify <file> -R <owner>/<repo> \
  --signer-workflow axnic/.github/.github/workflows/pulumi.publish.yaml
```

## Example caller

The `publish` job of the release caller (full file in [Releases](Releases.md)):

```yaml
  publish:
    needs: prepare
    permissions:
      contents: write
      id-token: write
      attestations: write
    uses: axnic/.github/.github/workflows/pulumi.publish.yaml@main
    with:
      tag: ${{ needs.prepare.outputs.tag }}
      version: ${{ needs.prepare.outputs.version }}
      sdks: '["nodejs","python","dotnet"]'
    secrets: inherit
```

## Known limitations

- Trusted publishing from a reusable workflow is unverified: whether npm and NuGet match the caller file
  or the central workflow is settled by the first real release, and the registry policies may need
  adjusting.
- npm needs npm >= 11.5.1 from the repository's mise node for OIDC.
- The Pulumi release is published (not left as a draft) by design, so there is no manual review of the notes.
- The upload filter covers the goreleaser artifact types Archive, Checksum, Signature, Certificate and
  SBOM only.
- The `NUGET_USER` secret is an addition to the original contract.
- PyPI uses an API token with twine, as the previous workflows did, not trusted publishing.
