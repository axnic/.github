# Catalog of the central workflows of axnic/.github (see the contract in
# plans/CONTRACT.md) that this module can turn into caller files. Kept apart from
# main.tf so a new workflow or group is a one-file review.
#
# Adding a workflow:
#   1. add the reusable workflow to axnic/.github (`<group>.<action>.yaml`);
#   2. add an entry below: group, action (the caller's file stem), triggers (the
#      caller file name is `join(",", sort(triggers)).<action>.yaml`) and the
#      mise tasks the repository must define;
#   3. add its template (header, jobs, permissions, `with:`) under .github/workflows/templates/<group>/<action>.yaml.tftpl
#      (templates/ in this module is a symlink to that directory);
#   4. a workflow joins the group named by its `group` field: nothing else to wire.

locals {
  # ── Catalog ─────────────────────────────────────────────────────────────────
  # Key = central workflow stem (`<group>.<action>` in axnic/.github). Each
  # entry is one caller file `<sorted triggers>.<action>.yaml`, rendered from
  # templates/<group>/<action>.yaml.tftpl, which owns the job permissions and
  # the `with:` inputs (an unset setting is not passed: the central default applies).
  catalog = {
    "core.qa" = {
      group    = "core"
      action   = "qa"
      triggers = ["merge_group", "pull_request", "push"]
      tasks    = ["ci:commitlint"]
    }
    "core.review" = {
      group    = "core"
      action   = "review"
      triggers = ["issue_comment", "pull_request"]
      tasks    = []
    }
    "core.scan" = {
      group    = "core"
      action   = "scan"
      triggers = ["pull_request", "push", "schedule"]
      tasks    = []
    }
    "core.deps" = {
      group    = "core"
      action   = "deps"
      triggers = ["pull_request"]
      tasks    = []
    }
    "issues.stale" = {
      group    = "issues"
      action   = "stale"
      triggers = ["schedule", "workflow_dispatch"]
      tasks    = []
    }
    "go.test" = {
      group    = "go"
      action   = "test"
      triggers = ["pull_request", "push"]
      tasks    = ["ci:build", "ci:test", "ci:coverage"]
    }
    "release.prepare" = {
      group    = "release"
      action   = "release"
      triggers = ["workflow_dispatch"]
      tasks    = ["ci"]
    }
    "pulumi.codegen" = {
      group    = "pulumi"
      action   = "codegen"
      triggers = ["pull_request_target"]
      tasks    = []
    }
    "security.audit" = {
      group    = "security"
      action   = "audit"
      triggers = ["schedule", "workflow_dispatch"]
      tasks    = ["security:audit"]
    }
    "oss.scorecard" = {
      group    = "oss"
      action   = "scorecard"
      triggers = ["schedule", "workflow_dispatch"]
      tasks    = []
    }
    "oss.welcome" = {
      group    = "oss"
      action   = "welcome"
      triggers = ["pull_request_target"]
      tasks    = []
    }
    "e2e.sync" = {
      group    = "e2e"
      action   = "e2e-sync"
      triggers = ["schedule", "workflow_dispatch"]
      tasks    = ["ci:e2e:versions"]
    }
    "wiki.publish" = {
      group    = "wiki"
      action   = "wiki"
      triggers = ["push", "workflow_dispatch"]
      tasks    = []
    }
  }
}
