# axnic

Everything public about the projects of the [axnic](https://github.com/axnic) organisation lives
in this repository: the shared tooling, the conventions, the agent skills and the infrastructure
behind them. This wiki is generated from the `docs/` directory by [wiki.publish](wiki.publish.md):
do not edit it in the GitHub UI, open a pull request instead.

For the list of projects, see the [organisation profile](https://github.com/axnic).

## What you will find here

| Section                           | What it covers                                                                          |
| --------------------------------- | --------------------------------------------------------------------------------------- |
| [Central CI](Central-CI.md)       | The reusable workflows shared by every repository, and how their callers are generated. |
| [Skills](Skills.md)               | The agent skills (`skills/`) used across the projects, and how to use them.             |
| [Conventions](Conventions.md)     | File naming, workflow house style, security rules and commit conventions.               |
| [Releases](Releases.md)           | The two-stage release process, recovery and verification of the artifacts.              |
| [Mise-Tasks](Mise-Tasks.md)       | The mise tasks a repository must define for the central workflows.                      |
| [Adding-A-Repo](Adding-A-Repo.md) | Enabling the groups of workflows for a new repository.                                  |

## Repository layout

| Path                 | Content                                                                     |
| -------------------- | --------------------------------------------------------------------------- |
| `.github/workflows/` | Reusable workflows (`workflow_call` only) and this repository's own callers |
| `skills/`            | Agent skills, one directory per skill                                       |
| `docs/`              | This wiki                                                                   |
| `scripts/`           | Release and E2E tooling used by the workflows                               |
| `README.md`          | The public organisation profile (generated, do not edit by hand)            |

## Contributing

Commits follow [Conventional Commits](Conventions.md#commit-conventions) with a mandatory scope.
Setup and commands are described in `AGENTS.md` at the root of the repository.
