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
    name              = "pulumi-test"
    description       = "Test pulumi module"
    extra_topics      = ["my-extra-topic"]
    registry_packages = ["garage"]
    ci_workflow       = "ci.yaml"
    npm_packages      = ["@axnic/pulumi-test"]
    pypi_packages     = ["pulumi-test"]
    nuget_packages    = ["Axnic.Pulumi.Test"]
  }

  assert {
    condition     = output.project_info.type == "pulumi"
    error_message = "project_info.type should be 'pulumi'"
  }

  assert {
    condition     = length(output.project_info.badges) == 9
    error_message = "expected downloads, scorecard, CI, npm, PyPI, NuGet and Registry badges on top of the base badges"
  }

  assert {
    condition     = contains(output.project_info.topics, "pulumi")
    error_message = "project_info.topics missing default 'pulumi' topic"
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
    name     = "pulumi-invalid-features"
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
    name = "pulumi-defaults"
  }

  assert {
    condition     = length(output.project_info.badges) == 4
    error_message = "expected base + downloads + scorecard badges by default"
  }
}

# Workflows: pulumi defaults to core, go, security, pulumi, release.
run "workflows_defaults" {
  command = plan

  variables {
    name = "pulumi-workflows"
  }

  assert {
    condition = output.workflow_files == tolist([
      "merge_group,pull_request,push.qa.yaml",
      "pull_request,push,schedule.osv.yaml",
      "pull_request,push,schedule.scan.yaml",
      "pull_request,push.test.yaml",
      "pull_request_target.codegen.yaml",
      "schedule,workflow_dispatch.audit.yaml",
      "workflow_dispatch.release.yaml",
    ])
    error_message = "unexpected pulumi default callers: ${jsonencode(output.workflow_files)}"
  }
}

run "workflows_opt_out" {
  command = plan

  variables {
    name            = "pulumi-no-workflows"
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
    name     = "pulumi-bad-pr-agent"
    pr_agent = { monthly_budget_usd = 0 }
  }

  expect_failures = [
    var.pr_agent,
  ]
}
