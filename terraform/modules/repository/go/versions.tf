terraform {
  # modules/workflows (called from base) needs >= 1.9.
  required_version = ">= 1.9"

  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
    toml = {
      source  = "Tobotimus/toml"
      version = "~> 0.3.0"
    }
  }
}
