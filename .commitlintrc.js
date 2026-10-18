/*
 * Copyright (C) 2024 Alexandre Nicolaie (xunleii@users.noreply.github.com)
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *         http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 * ----------------------------------------------------------------------------
 */

/**
 * Commit format: gitsym (`type[scope]: Subject`), with a mandatory scope.
 * The types, the header and the body rules come from the shared config.
 *
 * @see {@link https://github.com/axnic/gitsym}
 */

/**
 * Allowed commit scopes, matching the project's top-level code areas.
 *
 * workflows  — Shared GitHub Actions workflows (.github/workflows/)
 * terraform  — Terraform configuration and caller templates (terraform/, .github/workflows/templates/)
 * profile    — Org profile page (README.md, generated)
 * docs       — Documentation (AGENTS.md, *.md at root)
 * deps       — Dependency updates (actions, npm dev-deps)
 * templates  — Workflow/file templates (.github/templates/)
 * skills     — Agent skills (skills/)
 * tooling    — Dev tooling (mise, rtunk, commitlint, editorconfig, …)
 */
const scopes = [
  "workflows",
  "terraform",
  "profile",
  "docs",
  "skills",
  "deps",
  "templates",
  "tooling",
];

/** @type {import('@commitlint/types').UserConfig} */
module.exports = {
  extends: ["@axnic/commitlint-config-gitsym"],
  rules: {
    "scope-enum": [2, "always", scopes],
    "scope-empty": [2, "never"],
  },
};
