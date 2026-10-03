# Terraform

Terraform configuration of the **axnic** GitHub organisation: the repositories, their security
settings and rulesets, the central CI callers, the PR-Agent keys and the organisation profile
README. It is applied by **HCP Terraform** (organisation `axnic`, workspace `Github`, VCS-driven on
this repository); locally, Terraform is only used to format, validate and test.

Overview for readers: the [Terraform wiki page](https://github.com/axnic/.github/wiki/Terraform).
First-time setup of the workspace and of the GitHub App: [bootstrap/README.md](bootstrap/README.md).

## Layout

```text
terraform/
├── bootstrap/           # Manual first-time setup guide (no code)
├── live/                # Root configuration, the apply target
│   ├── main.tf          # The two org-infrastructure repositories (.github, .github-private)
│   ├── projects.tf      # Active projects, and local.all_projects
│   ├── projects_archived.tf
│   ├── ci_app.tf        # CI app secrets of the repositories that need the bot
│   ├── pr_agent.tf      # PR-Agent budgets and allow-lists
│   ├── organization.tf  # Org profile README, rendered from local.all_projects
│   └── imports.tf       # One-shot adoption of existing repositories
└── modules/
    ├── repository/      # base, go, pulumi, pi_extension: one module per repository type
    ├── workflows/       # Caller workflows of a repository + mise-task guard
    ├── pr_agent/        # OpenRouter key and allow-list of a repository
    └── org_readme/      # Public and private profile READMEs
```

The caller templates of `modules/workflows` live in `.github/workflows/templates/` (the module's
`templates` is a symlink to it). The workspace must keep `terraform/` and
`.github/workflows/templates/` in its VCS trigger prefixes.

## Local commands

```sh
mise run tf:fmt        # terraform fmt -check -recursive
mise run tf:fmt:fix    # terraform fmt -recursive
mise run tf:validate   # init without backend, then validate terraform/live
mise run tf:test       # terraform test in every module that has *.tftest.hcl
```

Never run `terraform apply` locally against the workspace. The same checks run on pull requests in
`merge_group,pull_request,push.qa.yaml`.

## Variables

Workspace variables (set in HCP Terraform, never committed): `github_app_id`,
`github_app_installation_id`, `github_app_pem_file` (sensitive), `openrouter_management_key`
(sensitive), and optionally `ci_github_app_id`, `ci_github_app_installation_id`,
`ci_github_app_pem_file` (sensitive, see [CI-GitHub-App](https://github.com/axnic/.github/wiki/CI-GitHub-App))
and `pr_agent_extra_users`. Requires **Terraform >= 1.9**, also in the workspace settings.

## `project_info` contract

Every `repository/*` module exposes a `project_info` output consumed by `org_readme`: `name`, `url`,
`description`, `type` (`pi_extension`, `pulumi`, `go` or `other`), `archived`, `visibility`, `topics`,
`badges` and `pr_agent`. The exact shape is in `modules/org_readme/variables.tf`.

## Security defaults (`repository/base`)

Every managed repository gets secret scanning with push protection and vulnerability alerts (when
the plan allows it), branch deletion on merge, and a ruleset on the default branch. The details
are in `modules/repository/base`.

## Central CI callers

`repository/{base,go,pulumi}` call `modules/workflows` to commit thin caller workflows, which call the
reusable workflows of this repository, into each repository. Inputs: `workflow_groups` (null = default
of the type, `[]` = none), `workflows`, `custom_workflows`, `workflow_params`, `pr_agent` (no default;
never set a budget without the owner's decision).

- Merge the mise-task pull requests of each repository **before** the apply: the guard reads the
  default branch at plan time.
- The Terraform GitHub App (`github_app_id`) is a ruleset bypass actor (opt-out
  `terraform_app_bypass`) and needs `Contents: write` and `Workflows: write`.
- `required_status_checks` use the names `<caller job> / <called job>`, set after the first PR run.

## PR-Agent

Enable with `pr_agent = { monthly_budget_usd = N }` on a project in `projects.tf`. It creates, per
repository, an OpenRouter key `pr-agent-<repo>` (secret `OPENROUTER_API_KEY`) and the variable
`PR_AGENT_ALLOWED_USERS` (admins and maintainers of the repository, plus `pr_agent_extra_users`).
Roll a key with
`terraform apply -replace='module.pr_agent["<repo>"].openrouter_api_key.this'`.
