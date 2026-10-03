terraform {
  cloud {
    organization = "axnic"

    workspaces {
      name = "Github"
    }
  }

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
    openrouter = {
      source  = "OpenRouterTeam/openrouter"
      version = "~> 0.3.0"
    }
  }
}

provider "github" {
  owner = "axnic"

  app_auth {
    id              = var.github_app_id
    installation_id = var.github_app_installation_id
    pem_file        = var.github_app_pem_file
  }
}

provider "openrouter" {
  api_key = var.openrouter_management_key
}
