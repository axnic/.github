# go.publish - Release publish for Go (stage 2 of 2)

Group `go`. Central workflow: `.github/workflows/go.publish.yaml`. Second job of the release caller of a
Go repository (`needs: prepare`); see [Releases](Releases.md) and [release.prepare](release.prepare.md).

## Purpose

Builds the tag that [release.prepare](release.prepare.md) pushed and attaches the artifacts to the **draft**
release it created. Publishing the draft stays a manual step.

Job `publish`:

1. Checks out the tag and builds with goreleaser (the repository's `.goreleaser.yml`) without letting
   goreleaser publish anything (`--skip=publish`): archives, checksums, one SBOM per archive (`sboms`,
   syft) and a keyless cosign signature of the checksums file (`signs`, Sigstore bundle). The job
   fails when the configuration produces no signature or no SBOM. cosign and syft come from the
   repository's mise tools.
2. Uploads archives, checksums, signature bundle(s) and SBOMs to the draft release (`--clobber`: a re-run
   replaces them).
3. Records a SLSA build provenance attestation for every file listed in the checksums.

## When it runs

As the `publish` job of the release caller `workflow_dispatch.release.yaml`.

## Inputs

| Input        | Type    | Default | Notes                                                                                   |
| ------------ | ------- | ------- | --------------------------------------------------------------------------------------- |
| `tag`        | string  | -       | **Required.** The tag pushed by `release.prepare` (`v<version>`).                       |
| `version`    | string  | -       | **Required.** The version without `v`.                                                  |
| `prerelease` | boolean | `false` | Informational (`release.prepare` already flagged the draft); shown in the job name.     |

## Secrets

None (uses `GITHUB_TOKEN`).

## Permissions (granted by the caller)

`contents: write`, `id-token: write`, `attestations: write`

## Required mise tasks

None. Tools: go, cosign, syft; configuration: `.goreleaser.yml` with `sboms` and `signs`.

## Verification

The identity that signs is this central workflow, not the repository's caller. See
[Releases](Releases.md#verifying-a-release) for the `cosign verify-blob` and `gh attestation verify` commands.

## Example caller

The `publish` job of the release caller (full file in [Releases](Releases.md)):

```yaml
  publish:
    needs: prepare
    permissions:
      contents: write
      id-token: write
      attestations: write
    uses: axnic/.github/.github/workflows/go.publish.yaml@main
    with:
      tag: ${{ needs.prepare.outputs.tag }}
      version: ${{ needs.prepare.outputs.version }}
      prerelease: ${{ needs.prepare.outputs.prerelease == 'true' }}
    secrets: inherit
```

## Known limitations

- The upload filter covers the goreleaser artifact types Archive, Checksum, Signature, Certificate and
  SBOM only. A repository shipping raw binaries or packages would need the list extended.
- Goreleaser's own `release:` section is bypassed on purpose (the GitHub API does not return draft
  releases by tag, so goreleaser would create a second release).
- Keyless signing from a reusable workflow and the exact certificate identity are proven by the first
  real release, not by tests.
