test {
  parallel = false
}

# The GitHub provider is mocked (offline). The mocked mise config defines every
# task the default workflow groups require, so the mise-task guard of
# modules/workflows passes.
mock_provider "github" {
  mock_data "github_repository_file" {
    defaults = {
      content = <<-TOML
        [tasks."ci:commitlint"]
        run = "commitlint"
        [tasks."ci:build"]
        run = "go build ./..."
        [tasks."ci:test"]
        run = "go test ./..."
        [tasks."ci:coverage"]
        run = "go test -cover ./..."
        [tasks."security:audit"]
        run = "govulncheck ./..."
        [tasks.ci]
        depends = ["ci:test"]
      TOML
    }
  }

  mock_data "github_tree" {
    defaults = {
      entries = []
    }
  }
}

# 1) Basic plan test: ensure module accepts valid inputs and produces expected project_info shape.
run "valid_plan" {
  module {
    source = "./."
  }

  command = plan

  variables {
    name                   = "tf-base-test"
    description            = "Test repository for terraform module base"
    visibility             = "public"
    topics                 = ["tf-test"]
    required_status_checks = ["ci/test"]
    features               = ["issues", "wiki"]
  }

  assert {
    condition     = output.project_info.name == "tf-base-test"
    error_message = "project_info.name did not match the provided name"
  }

  assert {
    condition     = output.project_info.visibility == "public"
    error_message = "project_info.visibility did not match the provided visibility"
  }

  assert {
    condition     = contains(output.project_info.topics, "tf-test")
    error_message = "project_info.topics did not include the expected topic"
  }

  assert {
    condition     = length(output.project_info.badges) == 2
    error_message = "expected 2 default badges in project_info.badges"
  }
}

# 2) Validate input variable validation for `features`: disallowed values should fail validation.
run "invalid_features" {
  module {
    source = "./."
  }

  command = plan

  variables {
    name     = "tf-base-invalid-features"
    features = ["not-a-valid-feature"]
  }

  # We expect the validation on the input variable `features` to fail.
  expect_failures = [
    var.features,
  ]
}

# 3) Default features behaviour: omit `features` and ensure module still produces project_info output.
run "default_features" {
  module {
    source = "./."
  }

  command = plan

  variables {
    name        = "tf-base-default-features"
    description = "Ensure default features work"
  }

  assert {
    condition     = output.project_info.name == "tf-base-default-features"
    error_message = "project_info.name did not match for default-features run"
  }

  # default badges still present
  assert {
    condition     = length(output.project_info.badges) == 2
    error_message = "expected 2 default badges when using defaults"
  }
}

# 4) Workflows: base defaults to the core group (no AI review without pr_agent).
run "workflows_default_core" {
  command = plan

  variables {
    name = "tf-base-workflows"
  }

  assert {
    condition = output.workflow_files == tolist([
      "merge_group,pull_request,push.qa.yaml",
      "pull_request,push,schedule.scan.yaml",
      "pull_request.deps.yaml",
    ])
    error_message = "base must default to the core group: ${jsonencode(output.workflow_files)}"
  }
}

# 5) workflow_groups = [] disables every caller.
run "workflows_opt_out" {
  command = plan

  variables {
    name            = "tf-base-no-workflows"
    workflow_groups = []
  }

  assert {
    condition     = length(output.workflow_files) == 0
    error_message = "workflow_groups = [] must generate no caller"
  }
}

# 6) Archived repositories never get callers.
run "workflows_archived" {
  command = plan

  variables {
    name            = "tf-base-archived"
    archived        = true
    features        = []
    workflow_groups = ["core"]
  }

  assert {
    condition     = length(output.workflow_files) == 0
    error_message = "an archived repository must get no caller"
  }
}

# 7) pr_agent set: the AI Review caller is generated.
run "workflows_pr_agent" {
  command = plan

  variables {
    name     = "tf-base-pr-agent"
    pr_agent = { monthly_budget_usd = 5 }
  }

  assert {
    condition     = contains(output.workflow_files, "issue_comment,pull_request.review.yaml")
    error_message = "pr_agent must enable the AI Review caller"
  }
}

# 8) pr_agent budget must be > 0.
run "invalid_pr_agent_budget" {
  command = plan

  variables {
    name     = "tf-base-bad-pr-agent"
    pr_agent = { monthly_budget_usd = 0 }
  }

  expect_failures = [
    var.pr_agent,
  ]
}

# 9) Unknown workflow_params keys are refused (an object conversion would drop them).
run "invalid_workflow_params_key" {
  command = plan

  variables {
    name            = "tf-base-bad-params"
    workflow_params = { deps_merge_methd = "squash" }
  }

  expect_failures = [
    var.workflow_params,
  ]
}

# 10) The Terraform app is a bypass actor of the ruleset unless opted out.
run "terraform_app_bypass" {
  command = plan

  variables {
    name                  = "tf-base-bypass"
    terraform_app_id      = "123"
    ruleset_bypass_actors = [{ actor_id = 456, actor_type = "Integration", bypass_mode = "always" }]
  }

  assert {
    condition     = toset([for a in github_repository_ruleset.main.bypass_actors : a.actor_id]) == toset([123, 456])
    error_message = "ruleset must list both the CI app and the Terraform app as bypass actors"
  }

  assert {
    condition     = alltrue([for a in github_repository_ruleset.main.bypass_actors : a.actor_type == "Integration" && a.bypass_mode == "always"])
    error_message = "the Terraform app bypass must be an Integration with bypass_mode always"
  }
}

run "terraform_app_bypass_opt_out" {
  command = plan

  variables {
    name                 = "tf-base-no-bypass"
    terraform_app_id     = "123"
    terraform_app_bypass = false
  }

  assert {
    condition     = length(github_repository_ruleset.main.bypass_actors) == 0
    error_message = "terraform_app_bypass = false must not add the Terraform app"
  }
}
