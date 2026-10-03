variable "public_links" {
  type = list(object({
    label = string
    url   = string
  }))
  description = "Important links shown on both public and private profiles (site, docs, etc.)."
  default     = []
}

variable "private_links" {
  type = list(object({
    label = string
    url   = string
  }))
  description = "Internal-only links shown on the private profile (runbooks, dashboard, etc.)."
  default     = []
}

variable "projects" {
  description = "List of project_info objects collected from all repository/* modules."
  type = list(object({
    name        = string
    url         = string
    description = string
    type        = string
    visibility  = string
    archived    = optional(bool, false)
    topics      = list(string)
    badges      = list(string) # Flat list of Markdown badge strings
  }))
  default = []
}
