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

run "valid_plan" {
  module {
    source = "./."
  }

  command = plan

  variables {
    name         = "go-test"
    description  = "Test go module"
    extra_topics = ["my-extra-topic"]
    go_modules   = ["github.com/axnic/go-test"]
    ci_workflow  = "ci.yaml"
  }

  assert {
    condition     = output.project_info.type == "go"
    error_message = "project_info.type should be 'go'"
  }

  # base 2 + go-version 1 + downloads + scorecard + CI + 1 per go module
  assert {
    condition     = length(output.project_info.badges) == 7
    error_message = "expected go-version, downloads, scorecard, CI and pkg.go.dev badges in project_info.badges"
  }

  assert {
    condition     = contains(output.project_info.topics, "go")
    error_message = "project_info.topics missing default 'go' topic"
  }

  assert {
    condition     = contains(output.project_info.topics, "golang")
    error_message = "project_info.topics missing default 'golang' topic"
  }

  assert {
    condition     = contains(output.project_info.topics, "my-extra-topic")
    error_message = "project_info.topics did not include extra topic"
  }
}

run "invalid_features" {
  module {
    source = "./."
  }

  command = plan

  variables {
    name     = "go-invalid-features"
    features = ["not_a_feature"]
  }

  expect_failures = [
    var.features,
  ]
}

run "defaults" {
  module {
    source = "./."
  }

  command = plan

  variables {
    name = "go-defaults"
  }

  assert {
    condition     = length(output.project_info.badges) == 5
    error_message = "expected base + go-version + downloads + scorecard badges by default"
  }
}

# Workflows: go defaults to core, go, security, release (+ wiki with the wiki feature).
run "workflows_defaults" {
  command = plan

  variables {
    name = "go-workflows"
  }

  assert {
    condition = output.workflow_files == tolist([
      "merge_group,pull_request,push.qa.yaml",
      "pull_request,push,schedule.osv.yaml",
      "pull_request,push,schedule.scan.yaml",
      "pull_request,push.test.yaml",
      "pull_request.deps.yaml",
      "schedule,workflow_dispatch.audit.yaml",
      "workflow_dispatch.release.yaml",
    ])
    error_message = "unexpected go default callers: ${jsonencode(output.workflow_files)}"
  }
}

run "workflows_defaults_wiki" {
  command = plan

  variables {
    name     = "go-workflows-wiki"
    features = ["issues", "wiki"]
  }

  assert {
    condition     = contains(output.workflow_files, "push,workflow_dispatch.wiki.yaml")
    error_message = "the wiki feature must add the wiki group by default"
  }
}

run "workflows_opt_out" {
  command = plan

  variables {
    name            = "go-no-workflows"
    workflow_groups = []
  }

  assert {
    condition     = length(output.workflow_files) == 0
    error_message = "workflow_groups = [] must generate no caller"
  }
}

run "invalid_pr_agent_budget" {
  command = plan

  variables {
    name     = "go-bad-pr-agent"
    pr_agent = { monthly_budget_usd = -1 }
  }

  expect_failures = [
    var.pr_agent,
  ]
}
