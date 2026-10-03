terraform {
  # Provider-defined functions (provider::toml::decode) need Terraform >= 1.8; validations that
  # refer to other variables and locals need >= 1.9.
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
