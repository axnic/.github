terraform {
  required_version = ">= 1.9"

  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
    openrouter = {
      source  = "OpenRouterTeam/openrouter"
      version = "~> 0.3.0"
    }
  }
}
