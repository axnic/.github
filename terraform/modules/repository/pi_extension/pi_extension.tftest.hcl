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

# 1) Valid plan: supply typical inputs including an npm package and assert outputs
run "valid_plan" {
  module {
    source = "./."
  }

  command = plan

  variables {
    name                   = "pi-extension-test"
    description            = "Test pi_extension module"
    visibility             = "public"
    required_status_checks = ["ci/test"]
    features               = ["issues", "discussions"]
    extra_topics           = ["my-extra-topic"]
    npm_packages           = ["@axnic/pi-extension-test"]
  }

  # ensure module merges/overrides base.project_info and adds pi_extension-specific fields
  assert {
    condition     = output.project_info.type == "pi_extension"
    error_message = "project_info.type should be 'pi_extension'"
  }

  # base provides 2 default badges; pi_extension should add the npm badge -> total 3
  assert {
    condition     = length(output.project_info.badges) == 3
    error_message = "expected an extra npm badge to be present in project_info.badges"
  }

  # topics should include both the module defaults (pi-agent, extension) and extra_topics
  assert {
    condition     = contains(output.project_info.topics, "my-extra-topic")
    error_message = "project_info.topics did not include extra topic"
  }

  assert {
    condition     = contains(output.project_info.topics, "pi-agent")
    error_message = "project_info.topics missing default 'pi-agent' topic"
  }

  assert {
    condition     = output.project_info.visibility == "public"
    error_message = "project_info.visibility did not match provided visibility"
  }
}

# 2) Invalid features: provide a disallowed features value and expect variable validation to fail
run "invalid_features" {
  module {
    source = "./."
  }

  command = plan

  variables {
    name     = "pi-extension-invalid-features"
    features = ["not_a_feature"]
  }

  # Expect the validation on var.features to fail
  expect_failures = [
    var.features,
  ]
}

# 3) Defaults: omit optional fields (no npm, no extra topics) and validate default behaviour
run "defaults" {
  module {
    source = "./."
  }

  command = plan

  variables {
    name        = "pi-extension-defaults"
    description = "Validate default behaviour"
  }

  assert {
    condition     = output.project_info.name == "pi-extension-defaults"
    error_message = "project_info.name did not match for defaults run"
  }

  # When no npm_packages supplied, badges should equal the 2 defaults from base
  assert {
    condition     = length(output.project_info.badges) == 2
    error_message = "expected only default badges when no npm_packages is supplied"
  }

  # Default features include 'issues' so plan should succeed and produce project_info
  assert {
    condition     = output.project_info.visibility == "public"
    error_message = "default visibility expected to be public"
  }
}
