# Releases

A release is cut from one caller, `workflow_dispatch.release.yaml`, with two chained jobs:

| Stage | Job       | Workflow                                                                                   | Result                                                                     |
| ----- | --------- | ------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------- |
| 1     | `prepare` | [release.prepare](release.prepare.md)                                                      | version computed, checks run, annotated tag pushed, **draft** release with notes |
| 2     | `publish` | [go.publish](go.publish.md) (Go repositories) or [pulumi.publish](pulumi.publish.md) (Pulumi providers) | artifacts built, signed and attached; packages pushed to the registries    |

Both stages are in **one caller** on purpose: the tag is pushed with `GITHUB_TOKEN`, and a push made
with it never triggers another workflow. A separate "on tag" workflow would therefore never start.
Consequently **pushing a tag by hand publishes nothing**: releases go through the dispatch.

## Dispatching a release

Run the workflow **Release** from the Actions tab of the repository, on the **default branch**, with
exactly one of two inputs:

| Input     | Meaning                                                                                              |
| --------- | ---------------------------------------------------------------------------------------------------- |
| `bump`    | `auto` (default), `patch`, `minor`, `major` or `manual` (release the exact `version`).               |
| `version` | An exact version without the leading `v`: `0.13.0`, `0.13.0-rc.1`; only with `bump=manual`.          |
| `notes`   | Optional. Release notes used as is; nothing is generated.                                            |

The Release caller turns `bump=manual` into an empty `bump` for the reusable workflow, which still requires
exactly one of the two: `manual` without `version`, or any other bump together with a `version`, fails the first step before
anything else runs. `rc-*` bumps
do not exist: a release candidate is cut by passing `version` (`0.13.0-rc.1`).

- `bump=patch|minor|major` starts from the last **stable** tag (`vX.Y.Z` without prerelease).
- `bump=auto` reads the commits since the last stable tag: a breaking change gives **major** (a 0.x
  project goes to 1.0.0), a feature gives **minor**, anything else **patch**. Both rtunk's symbol
  convention and Conventional Commits are understood. A breaking change is `+!`/`~!`/`-!`, `type!:` /
  `type(scope)!:` or a `BREAKING CHANGE:` footer.

### Rules

- **Default branch only.** Every release, release candidates included, is cut from the default
  branch. Any other ref fails.
- **Never below an existing tag.** A `bump` that would land below the highest existing tag
  (a release candidate included, for example `patch` while `v0.13.0-rc.2` exists) is refused: pass
  `version` explicitly. This is also how a hotfix on an older line is released.
- **`auto` needs new commits.** With no commit since the last stable tag, it fails with
  "nothing to release".
- **`version` must be new**: an existing tag is refused.
- **A commit that already carries a `vX.Y.Z` tag is never released again** (see recovery below).

## What `prepare` does

1. Computes the version (`scripts/release-version.mjs`, taken from `axnic/.github` at `main`) and
   enforces the rules above.
2. Runs `mise run ci` (lint, build, tests) on the commit about to be released.
3. Writes the notes. A deterministic draft is built from the commits since the previous tag (last stable
   tag for a stable release, last tag of any kind for a prerelease) and their pull requests. When
   `OPENROUTER_API_KEY` is available, a model writes the summary paragraph of the draft
   (`prompts/release-notes.md` is its system prompt); otherwise, or when the call fails, the
   deterministic draft is used as is. Notes never block a release.
4. Creates and pushes the annotated tag `v<version>`.
5. Creates the **draft** GitHub Release of that tag, marked prerelease when the version has a
   prerelease segment.

It outputs `tag`, `version` and `prerelease` (`'true'` or `'false'`, as strings: compare with `== 'true'`).

## What `publish` does

### Go repositories ([go.publish](go.publish.md))

Builds the tag with goreleaser using the repository's `.goreleaser.yml` (goreleaser does not publish
anything itself), then uploads archives, checksums, the Sigstore signature bundle of the checksums and the
SBOMs to the **draft** release, and records a SLSA build provenance attestation for every file in
the checksums. It fails if the configuration produces no signature or no SBOM. The draft stays a draft:
**publishing it is a manual step**.

### Pulumi providers ([pulumi.publish](pulumi.publish.md), jobs generated into the caller)

| Job        | What it does                                                                                                                 |
| ---------- | ---------------------------------------------------------------------------------------------------------------------------- |
| `provider` | goreleaser build, archives and checksums attached to the draft, attestation, then the release is **published** (no longer a draft). |
| `go-sdk`   | After `provider`: pushes the tag `sdk/go/<repository>/v<version>` on the release commit, so `go get` of the SDK resolves a clean version. Fails if `sdk/go/<repository>` does not exist. |
| `nodejs`   | `make nodejs_sdk`, then `npm stage publish --provenance` (dist-tag `next` for a prerelease, `latest` otherwise); the version is only staged until a maintainer approves it with 2FA.                    |
| `python`   | `make python_sdk`, then twine with `PYPI_API_TOKEN`. Skipped without the secret.                                             |
| `dotnet`   | `make dotnet_sdk`, then `dotnet nuget push`. Skipped without credentials.                                                    |

Pulumi releases are published without a manual review of the notes, because `pulumi plugin install`
can only download the provider from a published release and the SDKs are public as soon as they are
pushed. The SDK jobs run only for the languages listed in the `sdks` input.

## Partial failure and recovery

`prepare` refuses a commit that already carries a `vX.Y.Z` tag ("HEAD is already released"), so a
re-run never cuts a second version on the same commit. Depending on where it failed:

| Failure                                                   | State left behind          | What to do                                                                                          |
| --------------------------------------------------------- | -------------------------- | --------------------------------------------------------------------------------------------------- |
| In `prepare`, before the tag is pushed                    | nothing                    | Re-run (all jobs) or dispatch again.                                                                |
| In a `publish` job                                        | tag and draft release exist | **Re-run failed jobs**. Uploads use `--clobber` and every registry step is idempotent. Each SDK job can be re-run alone. |
| In `prepare`, after the tag is pushed (draft not created) | the tag, maybe the draft   | HEAD is now "already released", so re-running refuses. Delete the tag (`git push --delete origin vX.Y.Z`) and any draft release by hand, then dispatch again. |
| You want to start over                                    | tag and draft              | Same: delete the tag and the draft release, then dispatch again.                                    |

For Pulumi, delete the `sdk/go/<repository>/v<version>` tag as well if the `go-sdk` job already ran.
Versions already pushed to a registry (npm, PyPI, NuGet) cannot be reused: bump to a new version.

## Verifying a release

The signing identity of a release is the **central workflow** (the `job_workflow_ref` of the OIDC token),
not the repository's own release caller. The repository that ran it is pinned separately, otherwise a
release of any repository of the organisation would verify. Replace `<owner>/<repo>`, `<tag>`, `<file>`.

Go release (signature and attestation):

```sh
cosign verify-blob checksums.txt --bundle checksums.txt.sigstore.json \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  --certificate-identity-regexp '^https://github\.com/axnic/\.github/\.github/workflows/go\.publish\.yaml@(refs/heads/main|[0-9a-f]{40})$' \
  --certificate-github-workflow-repository <owner>/<repo>
sha256sum --ignore-missing -c checksums.txt            # shasum -a 256 -c on macOS
gh attestation verify <file> -R <owner>/<repo> \
  --signer-workflow axnic/.github/.github/workflows/go.publish.yaml
```

Pulumi provider archive (attestation only; the publish jobs run in the repository's own release caller):

```sh
gh attestation verify <file> -R <owner>/<repo>
```

Without `--signer-workflow`, `gh attestation verify -R` fails for artifacts built by a reusable workflow,
because it expects the signer to be in the repository itself. The identity ends with the commit the caller pins
(`@<commit-sha>`), or `refs/heads/main` for releases made before the callers were pinned.

## Prerequisites for publishing

Go repositories:

- `.goreleaser.yml` with `sboms` (syft) and `signs` (cosign, keyless); cosign and syft installed through
  the repository's mise tools. The caller grants `contents: write`, `id-token: write`,
  `attestations: write`.

Pulumi providers (secrets and registry-side configuration, all done by the owner):

| Registry | Authentication                                                                                                                                       |
| -------- | ---------------------------------------------------------------------------------------------------------------------------------------------------- |
| npm      | **Trusted publishing** (OIDC), bound to the **caller workflow file name**: the caller must stay named `workflow_dispatch.release.yaml`, and the trusted publisher must be configured on npmjs.com for that file. `NPM_TOKEN` is only a fallback when set. Needs npm >= 11.5.1 from the repository's mise node. |
| PyPI     | `PYPI_API_TOKEN` (API token, twine). Not trusted publishing. Without it the `python` job is skipped.                                                  |
| NuGet    | Trusted publishing through `NuGet/login` when the secret `NUGET_USER` (the nuget.org profile name) is set; otherwise `NUGET_API_KEY`; with neither the `dotnet` job is skipped. |

The repository also needs the Pulumi boilerplate Makefile targets (`nodejs_sdk`, `python_sdk`,
`dotnet_sdk`), a `.goreleaser.yml`, and the directory `sdk/go/<repository>` with its `go.mod`.

Trusted publishing from a reusable workflow has not been exercised yet: whether a registry matches the
caller file or the central workflow is confirmed by the first real release, and a policy may need to be
adjusted then.

## Example caller

As documented in `release.prepare.yaml` (the Terraform module generates the same structure; its
`bump` input may be a `choice` list instead of a free string):

```yaml
name: Release
on:
  workflow_dispatch:
    inputs:
      bump:
        description: "auto | patch | minor | major (leave empty when version is set)"
        type: string
        default: ""
      version:
        description: "Exact version without the leading v, e.g. 0.13.0-rc.1 (leave bump empty)"
        type: string
        default: ""
      notes:
        description: Release notes override (leave blank to generate them)
        type: string
        default: ""
permissions: {}
jobs:
  prepare:
    permissions:
      contents: write
      pull-requests: read
    uses: axnic/.github/.github/workflows/release.prepare.yaml@<commit-sha> # main
    with:
      bump: ${{ inputs.bump }}
      version: ${{ inputs.version }}
      notes: ${{ inputs.notes }}
    secrets: inherit
  publish:
    needs: prepare
    permissions:
      contents: write
      id-token: write
      attestations: write
    uses: axnic/.github/.github/workflows/go.publish.yaml@<commit-sha> # main
    with:
      tag: ${{ needs.prepare.outputs.tag }}
      version: ${{ needs.prepare.outputs.version }}
      prerelease: ${{ needs.prepare.outputs.prerelease == 'true' }}
    secrets: inherit
```
