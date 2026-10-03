# Skills

The `skills/` directory of this repository holds the **agent skills** shared across the axnic
projects. A skill is a directory with a `SKILL.md` (front matter `name` and `description`, then the
instructions) and optional `references/` loaded on demand, following the
[Agent Skills](https://agentskills.io) format, so it works with any agent that supports it.

## Available skills

| Skill                                                                       | What it does                                                                                                                    |
| --------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| [commit](https://github.com/axnic/.github/blob/main/skills/commit/SKILL.md) | Writes commit messages: Conventional Commits with a mandatory scope, a body that explains why, DCO sign-off and signed commits. |

## Using a skill

Copy or symlink the skill directory into the skills directory your agent reads (for example
`.claude/skills/<name>/` or `.agents/skills/<name>/` in a repository, or the user-level equivalent).
Each repository keeps its own scopes in its `.commitlintrc.js`: check them before relying on the
`commit` skill, see [Conventions](Conventions.md#commit-conventions).

## Adding a skill

1. Create `skills/<name>/SKILL.md` with a `name` equal to the directory name and a `description`
   that says **when** to use the skill.
2. Put long or rarely needed material in `skills/<name>/references/`, linked from `SKILL.md`.
3. Add the skill to the table above in the same pull request. Scope of the commit: `skills`.
