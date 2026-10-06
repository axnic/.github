# release.prepare - Release (stage 1 of 2)

Group `release` (common to Go and Pulumi repositories). Central workflow:
`.github/workflows/release.prepare.yaml`. First job of every repository's release caller. The whole
process, including recovery and verification, is described in [Releases](Releases.md).

## Purpose

Computes the version, verifies the commit, tags it and drafts the GitHub Release with its notes. The second
job of the same caller ([go.publish](go.publish.md) or [pulumi.publish](pulumi.publish.md), `needs: prepare`)
builds and attaches the artifacts. Both stages are in one caller because a tag pushed with
`GITHUB_TOKEN` triggers no other workflow.

Job `prepare`:

1. Computes the version (`scripts/release-version.mjs` of `axnic/.github`, checked out as a second
   repository). Exactly one of `bump` / `version` must be set, else the job fails before anything else.
2. Runs `mise run ci` on the commit about to be released.
3. Writes the release notes (a deterministic draft, plus an LLM summary paragraph when
   `OPENROUTER_API_KEY` is set), unless `notes` overrides them.
4. Creates and pushes the annotated tag `v<version>`.
5. Creates the **draft** GitHub Release of that tag, marked prerelease when the version has a prerelease
   segment.

## When it runs

Caller `workflow_dispatch.release.yaml`, on demand, from the **default branch** only.

## Inputs

| Input     | Type   | Default | Notes                                                                       |
| --------- | ------ | ------- | --------------------------------------------------------------------------- |
| `bump`    | string | `''`    | `auto`, `patch`, `minor` or `major`.                                        |
| `version` | string | `''`    | `X.Y.Z` or `X.Y.Z-<prerelease>`, no leading `v`.                            |
| `notes`   | string | `''`    | Release notes used as is (nothing is generated).                            |

Exactly one of `bump` / `version`. The rules (default branch, no bump below an existing tag, `auto` needs
new commits) are in [Releases](Releases.md#rules).

## Outputs

| Output       | Value                                                  |
| ------------ | ------------------------------------------------------ |
| `tag`        | `v<version>`                                           |
| `version`    | `<version>` without `v`                                |
| `prerelease` | `'true'` or `'false'` (string; compare with `== 'true'`) |

## Secrets

| Secret               | Required | Notes                                                  |
| -------------------- | -------- | ------------------------------------------------------ |
| `OPENROUTER_API_KEY` | no       | Without it the notes stay deterministic.                |

## Permissions (granted by the caller)

`contents: write` (tag, draft release) and `pull-requests: read` (the pull requests behind the commits,
for the notes). Both are needed: a called job cannot exceed what the caller grants.

## Required mise tasks

`ci` (required).

## Example caller

See [Releases](Releases.md#example-caller) for the full release caller. The `prepare` job:

```yaml
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
```

## Known limitations

- The scripts and the prompt come from `axnic/.github` at `main`, not from the ref the caller pins.
- The default-branch guard compares the caller's ref with the repository's default branch; run locally
  with an empty `DEFAULT_BRANCH` the script does not apply it.
- If `prepare` fails after the tag push, the tag and any draft must be deleted by hand before dispatching
  again ([Releases](Releases.md#partial-failure-and-recovery)).
- A breaking change on a `0.x` version with `bump=auto` gives `1.0.0`.
- The OpenRouter call and the tag push with `GITHUB_TOKEN` can only be proven on a real run.
