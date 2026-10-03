mock_provider "github" {
  mock_data "github_collaborators" {
    defaults = {
      collaborator = [
        { login = "zoe", permission = "admin", type = "User" },
        { login = "alice", permission = "maintain", type = "User" },
        { login = "bob", permission = "push", type = "User" },
        { login = "dependabot", permission = "admin", type = "Bot" },
      ]
    }
  }
}

mock_provider "openrouter" {
  mock_resource "openrouter_api_key" {
    defaults = { key = "sk-or-mock" }
  }
}

variables {
  repository         = "demo"
  monthly_budget_usd = 25
  management_key_set = true
}

run "key_secret_and_variable" {
  command = apply

  assert {
    condition     = openrouter_api_key.this.name == "pr-agent-demo" && openrouter_api_key.this.limit == 25 && openrouter_api_key.this.limit_reset == "monthly"
    error_message = "key must be named pr-agent-<repo> with the monthly limit"
  }
  assert {
    condition     = github_actions_secret.openrouter_api_key.secret_name == "OPENROUTER_API_KEY" && github_actions_secret.openrouter_api_key.repository == "demo"
    error_message = "secret missing"
  }
  assert {
    condition     = github_actions_variable.allowed_users.variable_name == "PR_AGENT_ALLOWED_USERS"
    error_message = "variable missing"
  }
}

run "allow_list_composition" {
  command = apply
  variables {
    extra_users = ["alice", "carol"]
  }

  assert {
    condition     = github_actions_variable.allowed_users.value == jsonencode(["alice", "carol", "zoe"])
    error_message = "expected admins+maintainers+extra, deduped, sorted, bots and push users excluded"
  }
}

run "empty_list_fails" {
  command = plan
  override_data {
    target = data.github_collaborators.this
    values = { collaborator = [] }
  }

  expect_failures = [github_actions_variable.allowed_users]
}

run "management_key_required" {
  command = plan
  variables {
    management_key_set = false
  }

  expect_failures = [openrouter_api_key.this]
}

run "invalid_extra_user" {
  command = plan
  variables {
    extra_users = ["bad user"]
  }

  expect_failures = [var.extra_users]
}

run "invalid_budget" {
  command = plan
  variables {
    monthly_budget_usd = 0
  }

  expect_failures = [var.monthly_budget_usd]
}
