# Offline tests: the GitHub provider is mocked. The mise config of the
# repository is the mocked `content` of every candidate file, plus file tasks
# from the mocked tree. provider::toml::decode runs for real.

mock_provider "github" {
  mock_data "github_repository_file" {
    defaults = {
      # Also the mock of the central workflows read for the pins in the callers.
      commit_sha = "0123456789abcdef0123456789abcdef01234567"
      content    = <<-TOML
        [tasks."ci:commitlint"]
        run = "commitlint"
        [tasks."ci:build"]
        run = "go build ./..."
        [tasks."ci:test"]
        run = "go test ./..."
        [tasks.ci]
        depends = ["ci:test"]
        [tasks."security:audit"]
        run = "govulncheck ./..."
      TOML
    }
  }

  # ci:coverage is a file task.
  mock_data "github_tree" {
    defaults = {
      entries = [
        { path = ".mise/tasks/ci/coverage", type = "blob", mode = "100755", size = 10, sha = "x" },
        { path = ".mise/tasks/ci", type = "tree", mode = "040000", size = 0, sha = "y" },
      ]
    }
  }
}

variables {
  repository = "demo"
}

# 1) File naming: `<sorted triggers>.<action>.yaml`, core without review.
run "core_naming" {
  command = plan

  variables {
    workflow_groups = ["core"]
  }

  assert {
    condition = output.files == tolist([
      "merge_group,pull_request,push.qa.yaml",
      "pull_request,push,schedule.scan.yaml",
    ])
    error_message = "unexpected core caller files: ${jsonencode(output.files)}"
  }

  assert {
    condition     = strcontains(github_repository_file.caller["merge_group,pull_request,push.qa.yaml"].content, "uses: axnic/.github/.github/workflows/core.qa.yaml@0123456789abcdef0123456789abcdef01234567 # main\n    secrets: inherit\n    permissions:\n      contents: read\n")
    error_message = "qa caller must call core.qa with secrets: inherit and contents: read"
  }

  assert {
    condition     = startswith(github_repository_file.caller["merge_group,pull_request,push.qa.yaml"].content, "# yaml-language-server: $schema=https://json.schemastore.org/github-workflow.json\n")
    error_message = "callers must start with the schema line"
  }

}

# 2) review only with pr_agent_enabled.
run "review_needs_pr_agent" {
  command = plan

  variables {
    workflow_groups  = ["core"]
    pr_agent_enabled = true
  }

  assert {
    condition     = contains(output.files, "issue_comment,pull_request.review.yaml")
    error_message = "review caller expected when pr_agent_enabled"
  }
}

# 3) Group expansion: pulumi includes go; release publishes with pulumi.
run "pulumi_includes_go" {
  command = plan

  variables {
    workflow_groups = ["pulumi", "release"]
  }

  assert {
    condition     = contains(output.files, "pull_request,push.test.yaml") && contains(output.files, "pull_request_target.codegen.yaml")
    error_message = "pulumi must generate go.test and pulumi.codegen: ${jsonencode(output.files)}"
  }

  assert {
    condition     = strcontains(github_repository_file.caller["workflow_dispatch.release.yaml"].content, "  nodejs:\n    name: 📦 Node.js SDK (npm)\n    needs: [prepare, provider]") && strcontains(github_repository_file.caller["workflow_dispatch.release.yaml"].content, "  dotnet:\n") && strcontains(github_repository_file.caller["workflow_dispatch.release.yaml"].content, "  python:\n") && !strcontains(github_repository_file.caller["workflow_dispatch.release.yaml"].content, "pulumi.publish.yaml")
    error_message = "release of a pulumi repo must carry its publish jobs itself (npm and NuGet trusted publishing need the repository's own workflow), not call pulumi.publish"
  }

  assert {
    condition     = strcontains(github_repository_file.caller["pull_request,push.test.yaml"].content, "      - .github/workflows/pull_request,push.test.yaml\n")
    error_message = "go.test paths must include the caller itself"
  }
}

# 4) Release of a Go repo: go.publish with prerelease.
run "release_go" {
  command = plan

  variables {
    workflow_groups = ["release"]
  }

  assert {
    condition     = strcontains(github_repository_file.caller["workflow_dispatch.release.yaml"].content, "uses: axnic/.github/.github/workflows/go.publish.yaml@0123456789abcdef0123456789abcdef01234567 # main")
    error_message = "release must default to go.publish"
  }

  assert {
    condition     = strcontains(github_repository_file.caller["workflow_dispatch.release.yaml"].content, "prerelease: \"$${{ needs.prepare.outputs.prerelease == 'true' }}\"")
    error_message = "go.publish must receive prerelease from prepare"
  }
}



# 6) A required mise task is missing: only the guard (postcondition of the
# tree read) may fail. The positive control is e2e_sync below.
run "missing_mise_task" {
  command = plan

  variables {
    workflow_groups = ["e2e"]
  }

  expect_failures = [data.github_tree.default_branch]
}

# 7) issues group without the issues feature.
run "issues_without_feature" {
  command = plan

  variables {
    workflow_groups = ["issues"]
    features        = ["wiki"]
  }

  expect_failures = [var.workflow_groups]
}

run "issues_single_without_feature" {
  command = plan

  variables {
    workflows = [{ workflow = "issues.stale" }]
  }

  expect_failures = [var.workflows]
}

run "issues_with_feature" {
  command = plan

  variables {
    workflow_groups = ["issues"]
    features        = ["issues"]
    settings        = { stale_days = 30 }
  }

  assert {
    condition     = strcontains(github_repository_file.caller["schedule,workflow_dispatch.stale.yaml"].content, "days-before-stale: 30\n")
    error_message = "stale caller must pass days-before-stale"
  }
}

# 8) Single catalog entry without its group.
run "single_workflow" {
  command = plan

  variables {
    workflows = [{ workflow = "pulumi.codegen" }]
  }

  assert {
    condition     = output.files == tolist(["pull_request_target.codegen.yaml"])
    error_message = "only the codegen caller expected: ${jsonencode(output.files)}"
  }
}

# 9) Custom workflow: named from its triggers.
run "custom_workflow" {
  command = plan

  variables {
    custom_workflows = [{
      action   = "nightly"
      triggers = ["workflow_dispatch", "schedule"]
      template = "./tests/custom.yaml.tftpl"
      vars     = { cron = "0 3 * * *" }
    }]
  }

  assert {
    condition     = output.files == tolist(["schedule,workflow_dispatch.nightly.yaml"])
    error_message = "custom caller must be named from its sorted triggers: ${jsonencode(output.files)}"
  }
}

# 10) Custom workflow whose declared triggers do not match its `on:`.
run "custom_workflow_trigger_mismatch" {
  command = plan

  variables {
    custom_workflows = [{
      action   = "nightly"
      triggers = ["schedule"]
      template = "./tests/custom.yaml.tftpl"
      vars     = { cron = "0 3 * * *" }
    }]
  }

  expect_failures = [github_repository_file.caller]
}

# 11) Custom workflow action naming.
run "custom_workflow_bad_action" {
  command = plan

  variables {
    custom_workflows = [{
      action   = "Nightly Build"
      triggers = ["schedule"]
      template = "./tests/custom.yaml.tftpl"
    }]
  }

  expect_failures = [var.custom_workflows]
}

# 12) Release caller shape: dispatch inputs and the prepare -> publish chain.
run "release_shape" {
  command = plan

  variables {
    workflow_groups = ["release"]
  }

  assert {
    condition = alltrue([
      for s in [
        "  workflow_dispatch:\n    inputs:\n      bump:\n",
        "      version:\n",
        "uses: axnic/.github/.github/workflows/release.prepare.yaml@0123456789abcdef0123456789abcdef01234567 # main",
        "    needs: prepare\n",
        "      bump: \"$${{ inputs.bump }}\"\n",
        "  prepare:\n",
        "    permissions:\n      contents: write\n      pull-requests: read\n",
        "  # publish — build the artifacts of the draft GitHub Release, from go.publish\n",
        "#   prepare — run `mise run ci`",
        "      tag: \"$${{ needs.prepare.outputs.tag }}\"\n",
      ] : strcontains(github_repository_file.caller["workflow_dispatch.release.yaml"].content, s)
    ])
    error_message = "release caller must expose bump/version and chain prepare -> publish"
  }
}

# 13) Explicit publish = pulumi without the pulumi group: only the listed SDKs get a publish job.
run "release_pulumi_sdks" {
  command = plan

  variables {
    workflow_groups = ["release"]
    publish         = "pulumi"
    settings        = { pulumi_sdks = ["nodejs"] }
  }

  assert {
    condition     = strcontains(github_repository_file.caller["workflow_dispatch.release.yaml"].content, "  provider:\n") && strcontains(github_repository_file.caller["workflow_dispatch.release.yaml"].content, "  go-sdk:\n") && strcontains(github_repository_file.caller["workflow_dispatch.release.yaml"].content, "  nodejs:\n") && !strcontains(github_repository_file.caller["workflow_dispatch.release.yaml"].content, "  python:\n") && !strcontains(github_repository_file.caller["workflow_dispatch.release.yaml"].content, "  dotnet:\n")
    error_message = "only the SDKs of settings.pulumi_sdks must get a publish job"
  }

  # The Terraform escapes must leave the GitHub expressions and the shell variables intact.
  assert {
    condition     = strcontains(github_repository_file.caller["workflow_dispatch.release.yaml"].content, "ref: refs/tags/$${{ needs.prepare.outputs.tag }}") && strcontains(github_repository_file.caller["workflow_dispatch.release.yaml"].content, "SDK_TAG=\"$${SDK_DIR}/$${TAG}\"")
    error_message = "expressions and shell variables of the publish jobs must be rendered verbatim"
  }
}

# 14) E2E: only the sync caller (per-version callers belong to e2e.sync),
# Monday 03:00 UTC, central defaults for commit-subject / readme-path; only
# ci:e2e:versions is required (ci:e2e belongs to the per-version callers).
run "e2e_sync" {
  command = plan

  variables {
    workflow_groups = ["e2e"]
  }

  override_data {
    target = data.github_repository_file.mise_config
    values = {
      content = <<-TOML
        [tasks."ci:e2e:versions"]
        run = "echo v2.3.0"
      TOML
    }
  }

  assert {
    condition     = output.files == tolist(["schedule,workflow_dispatch.e2e-sync.yaml"])
    error_message = "e2e must only generate the sync caller: ${jsonencode(output.files)}"
  }

  assert {
    condition = alltrue([
      for s in [
        "name: E2E Sync\n",
        "    - cron: 0 3 * * 1\n",
        "  workflow_dispatch: {}\n",
        "uses: axnic/.github/.github/workflows/e2e.sync.yaml@0123456789abcdef0123456789abcdef01234567 # main",
        "  # sync — add/remove the per-version E2E callers",
      ] : strcontains(github_repository_file.caller["schedule,workflow_dispatch.e2e-sync.yaml"].content, s)
    ])
    error_message = "unexpected e2e-sync caller"
  }

  assert {
    condition     = !strcontains(github_repository_file.caller["schedule,workflow_dispatch.e2e-sync.yaml"].content, "commit-subject") && !strcontains(github_repository_file.caller["schedule,workflow_dispatch.e2e-sync.yaml"].content, "readme-path")
    error_message = "unset e2e inputs must not be rendered"
  }
}

run "e2e_sync_overrides" {
  command = plan

  variables {
    workflow_groups = ["e2e"]
    settings        = { e2e_commit_subject = "ci[ci]: Sync E2E callers", e2e_readme_path = "docs/README.md" }
  }

  override_data {
    target = data.github_repository_file.mise_config
    values = { content = "[tasks.\"ci:e2e:versions\"]\nrun = \"echo v1\"\n" }
  }

  assert {
    condition     = strcontains(github_repository_file.caller["schedule,workflow_dispatch.e2e-sync.yaml"].content, "      commit-subject: \"ci[ci]: Sync E2E callers\"\n") && strcontains(github_repository_file.caller["schedule,workflow_dispatch.e2e-sync.yaml"].content, "      readme-path: docs/README.md\n")
    error_message = "e2e overrides must be passed"
  }
}

# 15) review inputs and the branch override.
run "review_inputs_and_branch" {
  command = plan

  variables {
    workflows        = [{ workflow = "core.review" }]
    pr_agent_enabled = true
    branch           = "tf/workflows"
    settings         = { review_model = "openrouter/x/y" }
  }

  assert {
    condition     = strcontains(github_repository_file.caller["issue_comment,pull_request.review.yaml"].content, "model: openrouter/x/y\n") && !strcontains(github_repository_file.caller["issue_comment,pull_request.review.yaml"].content, "fallback-model")
    error_message = "review must pass model and drop the unset fallback-model"
  }

  assert {
    condition     = github_repository_file.caller["issue_comment,pull_request.review.yaml"].branch == "tf/workflows"
    error_message = "callers must be committed to var.branch"
  }
}

# 16) review explicitly requested without pr_agent_enabled: refused (a group
# only skips it, see core_naming).
run "review_without_pr_agent" {
  command = plan

  variables {
    workflows = [{ workflow = "core.review" }]
  }

  expect_failures = [var.workflows]
}

run "unknown_single_workflow" {
  command = plan

  variables {
    workflows = [{ workflow = "go.publish" }]
  }

  expect_failures = [var.workflows]
}

# 17) No mise config file at all (the data source yields null content on 404):
# decoding is skipped and file tasks alone satisfy the guard.
run "no_mise_config_file_tasks_only" {
  command = plan

  variables {
    workflows = [{ workflow = "core.qa" }]
  }

  override_data {
    target = data.github_repository_file.mise_config
    values = { content = null }
  }

  override_data {
    target = data.github_tree.default_branch
    values = {
      entries = [{ path = "mise-tasks/ci/commitlint", type = "blob", mode = "100755", size = 10, sha = "z" }]
    }
  }

  assert {
    condition     = output.files == tolist(["merge_group,pull_request,push.qa.yaml"])
    error_message = "file tasks must satisfy the guard when no mise config exists"
  }
}

# 18) Tasks are merged across the mise config files.
run "tasks_merged_across_files" {
  command = plan

  variables {
    workflow_groups = ["go"]
  }

  override_data {
    target = data.github_repository_file.mise_config["mise.toml"]
    values = { content = "[tasks.\"ci:build\"]\nrun = \"go build ./...\"\n" }
  }

  override_data {
    target = data.github_repository_file.mise_config[".mise.toml"]
    values = { content = null }
  }

  override_data {
    target = data.github_repository_file.mise_config[".config/mise.toml"]
    values = { content = "[tasks.\"ci:test\"]\nrun = \"go test ./...\"\n" }
  }

  assert {
    condition     = output.files == tolist(["pull_request,push.test.yaml"])
    error_message = "ci:build (mise.toml) + ci:test (.config/mise.toml) + ci:coverage (file task) must satisfy go.test"
  }
}

# 19) A custom workflow's required_tasks are enforced by the guard.
run "custom_workflow_missing_task" {
  command = plan

  variables {
    custom_workflows = [{
      action         = "nightly"
      triggers       = ["schedule", "workflow_dispatch"]
      template       = "./tests/custom.yaml.tftpl"
      required_tasks = ["ci:nightly"]
      vars           = { cron = "0 3 * * *" }
    }]
  }

  expect_failures = [data.github_tree.default_branch]
}

# 20) Values rendered into YAML are validated.
run "invalid_cron" {
  command = plan

  variables {
    settings = { scan_cron = "0 6 * *" }
  }

  expect_failures = [var.settings]
}

run "invalid_default_branch" {
  command = plan

  variables {
    default_branch = "main]"
  }

  expect_failures = [var.default_branch]
}

# 21) No caller: the repository is not read at all (new/empty repositories).
run "no_callers_no_reads" {
  command = plan

  assert {
    condition     = length(data.github_tree.default_branch) == 0 && length(data.github_repository_file.mise_config) == 0
    error_message = "the guard data sources must not be read without callers"
  }
}

# 6b) The ordering input must not defer the guard: with ready_after unknown at
# plan (computed by an overridden resource), the guard still fails at plan.
# The data sources read no pending value, so the failure stays a plan error.
run "guard_not_deferred_by_ready_after" {
  command = plan

  variables {
    workflow_groups = ["e2e"]
    ready_after     = timestamp()
  }

  expect_failures = [data.github_tree.default_branch]
}

# OSV-Scanner caller (security group): weekly cron by default, overridable and validated.
run "osv_caller" {
  command = plan

  variables {
    workflow_groups = ["security"]
    settings        = { osv_cron = "15 4 * * 2" }
  }

  assert {
    condition     = contains(output.files, "pull_request,push,schedule.osv.yaml") && strcontains(github_repository_file.caller["pull_request,push,schedule.osv.yaml"].content, "cron: 15 4 * * 2") && strcontains(github_repository_file.caller["pull_request,push,schedule.osv.yaml"].content, "security.osv.yaml@0123456789abcdef0123456789abcdef01234567 # main")
    error_message = "the OSV caller must use osv_cron and call security.osv: ${jsonencode(output.files)}"
  }
}

run "osv_default_cron" {
  command = plan

  variables {
    workflow_groups = ["security"]
  }

  assert {
    condition     = strcontains(github_repository_file.caller["pull_request,push,schedule.osv.yaml"].content, "cron: 30 5 * * 1")
    error_message = "the OSV caller must default to Monday 05:30 UTC"
  }
}

run "invalid_osv_cron" {
  command = plan

  variables {
    settings = { osv_cron = "30 5 * *" }
  }

  expect_failures = [var.settings]
}





run "yaml_scalars_plain_sentence" {
  command = plan

  variables {
    workflows = [{ workflow = "oss.welcome" }]
    settings  = { welcome_message = "Thanks for contributing!" }
  }

  assert {
    condition     = strcontains(github_repository_file.caller["pull_request_target.welcome.yaml"].content, "message: Thanks for contributing!\n")
    error_message = "a sentence without ': ' or ' #' must be plain"
  }
}

run "yaml_scalars_quoted_trailing_space" {
  command = plan

  variables {
    workflows = [{ workflow = "oss.welcome" }]
    settings  = { welcome_message = "Thanks " }
  }

  assert {
    condition     = strcontains(github_repository_file.caller["pull_request_target.welcome.yaml"].content, "message: \"Thanks \"\n")
    error_message = "a trailing space must stay quoted"
  }
}

# core.scan: the CodeQL languages are passed as a JSON array in a string (the central input), and
# left to the central default (Go) when unset.
run "scan_languages_override" {
  command = plan

  variables {
    workflow_groups = ["core"]
    settings        = { scan_languages = ["javascript-typescript"] }
  }

  assert {
    condition     = strcontains(github_repository_file.caller["pull_request,push,schedule.scan.yaml"].content, "languages: \"[\\\"javascript-typescript\\\"]\"\n")
    error_message = "core.scan must receive the languages as a JSON array string"
  }
}

run "scan_languages_default" {
  command = plan

  variables {
    workflow_groups = ["core"]
  }

  assert {
    condition     = !strcontains(github_repository_file.caller["pull_request,push,schedule.scan.yaml"].content, "languages:")
    error_message = "without scan_languages the central default must apply"
  }
}

# Plain YAML scalars when safe (the repositories' yamllint refuses redundant quotes), quoted when the
# value is not a safe plain string or would be read as another type. Tested through the welcome message.
run "yaml_scalars_plain_word" {
  command = plan

  variables {
    workflows = [{ workflow = "oss.welcome" }]
    settings  = { welcome_message = "docs/README.md" }
  }

  assert {
    condition     = strcontains(github_repository_file.caller["pull_request_target.welcome.yaml"].content, "message: docs/README.md\n")
    error_message = "a safe word must be plain"
  }
}

run "yaml_scalars_quoted_boolean" {
  command = plan

  variables {
    workflows = [{ workflow = "oss.welcome" }]
    settings  = { welcome_message = "true" }
  }

  assert {
    condition     = strcontains(github_repository_file.caller["pull_request_target.welcome.yaml"].content, "message: \"true\"\n")
    error_message = "a boolean-looking string must stay quoted"
  }
}

run "yaml_scalars_quoted_number" {
  command = plan

  variables {
    workflows = [{ workflow = "oss.welcome" }]
    settings  = { welcome_message = "1.20" }
  }

  assert {
    condition     = strcontains(github_repository_file.caller["pull_request_target.welcome.yaml"].content, "message: \"1.20\"\n")
    error_message = "a number-looking string must stay quoted"
  }
}

run "yaml_scalars_quoted_special" {
  command = plan

  variables {
    workflows = [{ workflow = "oss.welcome" }]
    settings  = { welcome_message = "feat: x # y" }
  }

  assert {
    condition     = strcontains(github_repository_file.caller["pull_request_target.welcome.yaml"].content, "message: \"feat: x # y\"\n")
    error_message = "a string with ': ' or ' #' must stay quoted"
  }
}

run "callers_pin_central_workflows_to_a_commit" {
  command = plan

  variables {
    workflow_groups = ["core"]
  }

  assert {
    condition     = strcontains(github_repository_file.caller["merge_group,pull_request,push.qa.yaml"].content, "core.qa.yaml@0123456789abcdef0123456789abcdef01234567 # main") && !strcontains(github_repository_file.caller["merge_group,pull_request,push.qa.yaml"].content, "@main\n")
    error_message = "the caller must pin the central workflow to the commit that last changed it, not to @main"
  }
}
