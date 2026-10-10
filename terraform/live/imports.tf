# One-shot adoption of repos that existed before Terraform managed them.
# Safe to delete once the apply has succeeded (import blocks are no-ops after).
#
# Only github_repository / branch_default / dependabot_security_updates are
# imported; the ruleset and scoped labels do not exist yet and are created.

import {
  to = module.rtunk.module.base.github_repository.this
  id = "rtunk"
}
import {
  to = module.rtunk.module.base.github_branch_default.this
  id = "rtunk"
}
import {
  to = module.rtunk.module.base.github_repository_dependabot_security_updates.this
  id = "rtunk"
}

import {
  to = module.pulumi_garage.module.base.github_repository.this
  id = "pulumi-garage"
}
import {
  to = module.pulumi_garage.module.base.github_branch_default.this
  id = "pulumi-garage"
}
import {
  to = module.pulumi_garage.module.base.github_repository_dependabot_security_updates.this
  id = "pulumi-garage"
}

import {
  to = module.pulumi_pocket_id.module.base.github_repository.this
  id = "pulumi-pocket-id"
}
import {
  to = module.pulumi_pocket_id.module.base.github_branch_default.this
  id = "pulumi-pocket-id"
}
import {
  to = module.pulumi_pocket_id.module.base.github_repository_dependabot_security_updates.this
  id = "pulumi-pocket-id"
}

import {
  to = module.medieval_claude.github_repository.this
  id = "medieval-claude"
}
import {
  to = module.medieval_claude.github_branch_default.this
  id = "medieval-claude"
}
import {
  to = module.medieval_claude.github_repository_dependabot_security_updates.this
  id = "medieval-claude"
}

import {
  to = module.argocd_extension_application_map.github_repository.this
  id = "argocd-extension-application-map"
}
import {
  to = module.argocd_extension_application_map.github_branch_default.this
  id = "argocd-extension-application-map"
}
import {
  to = module.argocd_extension_application_map.github_repository_dependabot_security_updates.this
  id = "argocd-extension-application-map"
}
