# Generates the thin caller workflows of one repository from the central
# reusable workflows of axnic/.github (see plans/CONTRACT.md), and refuses to
# plan when the repository lacks a mise task a caller needs.
#
# The guard reads the repository (mise config and git tree) at plan time, so the
# repository must already exist and have a commit on its default branch: for a
# brand-new repository apply the repository first, then this module (two-step
# apply, or `depends_on` on the repository at the call site).

locals {
  s = var.settings

  # The catalog of central workflows lives in catalog.tf (`local.catalog`).

  # ── Selection ───────────────────────────────────────────────────────────────
  groups  = distinct(flatten([for g in var.workflow_groups : g == "pulumi" ? ["go", "pulumi"] : [g]]))
  publish = coalesce(var.publish, contains(local.groups, "pulumi") ? "pulumi" : "go")

  # A group silently skips core.review without pr_agent_enabled; an explicit
  # `workflows` entry is refused by the validation of var.workflows instead.
  selected = distinct(concat(
    [for k, w in local.catalog : k if contains(local.groups, w.group) && (k != "core.review" || var.pr_agent_enabled)],
    [for w in var.workflows : w.workflow],
  ))

  # ── Rendering ───────────────────────────────────────────────────────────────
  catalog_callers = [
    for k in local.selected : merge(local.catalog[k], {
      template = "${path.module}/templates/${local.catalog[k].group}/${local.catalog[k].action}.yaml.tftpl"
    })
  ]

  custom_callers = [
    for c in var.custom_workflows : {
      group    = "custom"
      action   = c.action
      triggers = c.triggers
      tasks    = c.required_tasks
      template = c.template
      vars     = { vars = c.vars }
    }
  ]

  # YAML scalars of the string settings, for the caller templates: plain when that is safe (the
  # repositories' yamllint refuses redundant quotes), JSON-quoted, which is valid YAML, otherwise.
  # Not plain: anything outside a conservative character set (no `:`, `#`, quotes, braces,
  # leading indicator or trailing space) and what YAML would read as a boolean, a null or a number.
  y = {
    for k, v in local.s : k => (
      can(regex("^[A-Za-z0-9_./^(][A-Za-z0-9 _./()\\[\\]^@!?+=,;%$&*<>|~-]*$", v)) &&
      !can(regex(" $", v)) &&
      !can(regex("^(?i:true|false|null|yes|no|on|off|y|n)$", v)) &&
      !can(regex("^[-+.]?[0-9][0-9._eE+-]*$", v)) ? v : jsonencode(v)
    )
    if v != null && can(tostring(v)) && !can(tolist(v))
  }

  # Keyed by file name: a duplicate name is a plan error.
  callers = {
    for c in concat(local.catalog_callers, local.custom_callers) :
    "${join(",", sort(c.triggers))}.${c.action}.yaml" => merge(c, {
      content = "${trimspace(templatefile(c.template, merge(try(c.vars, {}), {
        repository     = var.repository
        default_branch = var.default_branch
        settings       = local.s
        y              = local.y
        publish        = local.publish
        caller         = "${join(",", sort(c.triggers))}.${c.action}.yaml"
      })))}\n"
    })
  }

  # Every required task with the group that requires it.
  required_tasks = distinct(flatten([
    for c in values(local.callers) : [for t in c.tasks : { task = t, group = c.group }]
  ]))
}

# ── Mise-task guard ─────────────────────────────────────────────────────────────
# Only read when the repository gets at least one caller. Reads the default
# branch. A missing file is not an error for this data source (404 -> null
# content), so every candidate is read and decoded in try().
data "github_repository_file" "mise_config" {
  for_each = length(local.callers) > 0 ? toset(["mise.toml", ".mise.toml", ".config/mise.toml"]) : toset([])

  repository = var.repository
  branch     = var.default_branch
  file       = each.key
}

locals {
  toml_tasks = flatten([
    for f in data.github_repository_file.mise_config :
    try(keys(provider::toml::decode(f.content).tasks), [])
  ])

  # File tasks (executables under a mise task directory) are not in the TOML:
  # `.mise/tasks/ci/test` is the task `ci:test`.
  file_task_path = "^(?:mise-tasks|\\.mise-tasks|mise/tasks|\\.mise/tasks|\\.config/mise/tasks)/(.+)$"
}

# The guard is the postcondition of the tree read (and only there), so a test
# expecting it to fail cannot pass for another reason. This data source errors
# on a repository without any commit (see the header of this file).
data "github_tree" "default_branch" {
  count = length(local.callers) > 0 ? 1 : 0

  repository = var.repository
  tree_sha   = var.default_branch
  recursive  = true

  lifecycle {
    postcondition {
      condition = alltrue([
        for r in local.required_tasks : contains(concat(local.toml_tasks, [
          for e in self.entries : replace(regex(local.file_task_path, e.path)[0], "/", ":")
          if e.type == "blob" && can(regex(local.file_task_path, e.path))
        ]), r.task)
      ])
      error_message = join("\n", [
        for r in local.required_tasks :
        "repo ${var.repository}: mise task `${r.task}` is missing, required by group `${r.group}` (see wiki Mise-Tasks)"
        if !contains(concat(local.toml_tasks, [
          for e in self.entries : replace(regex(local.file_task_path, e.path)[0], "/", ":")
          if e.type == "blob" && can(regex(local.file_task_path, e.path))
        ]), r.task)
      ])
    }
  }
}

# Ordering gate for the caller commits. Only github_repository_file depends on
# it; the data sources above must not, or the guard would be deferred to apply.
resource "terraform_data" "ready" {
  input = var.ready_after
}

# ── Callers ─────────────────────────────────────────────────────────────────────

resource "github_repository_file" "caller" {
  for_each = local.callers

  repository          = var.repository
  branch              = coalesce(var.branch, var.default_branch)
  file                = ".github/workflows/${each.key}"
  content             = each.value.content
  commit_message      = format(var.commit_message, each.key)
  overwrite_on_create = true

  # Commit the callers only once the guard passed.
  depends_on = [data.github_tree.default_branch, terraform_data.ready]

  lifecycle {
    # The file name must tell the truth: the rendered `on:` keys are exactly
    # the declared triggers. YAML 1.1 decodes the key `on` as boolean true,
    # hence the "true" fallback.
    precondition {
      condition = sort(each.value.triggers) == sort(keys(try(
        yamldecode(each.value.content)["on"],
        yamldecode(each.value.content)["true"],
        {},
      )))
      error_message = "repo ${var.repository}: ${each.key} declares triggers [${join(", ", sort(each.value.triggers))}] but its template's `on:` does not match them."
    }
  }
}
