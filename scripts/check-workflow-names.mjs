#!/usr/bin/env node
// Checks the naming convention of every file in .github/workflows/:
//   central (on: workflow_call only)  ->  <group>.<action>.yaml
//   caller  (anything else)           ->  <triggers>.<action>.yaml
//       with <triggers> = the `on:` keys, sorted alphabetically, comma separated.
// Usage: node scripts/check-workflow-names.mjs [workflows-dir]   |   --self-test
// ponytail: `on:` parsed with a line scanner (block map/list, inline list, scalar, any indent, quoted keys); flow maps are
// reported as unsupported. No YAML dep; use a parser if that ever bites.
import { mkdtempSync, mkdirSync, readdirSync, readFileSync, statSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const unq = (k) => k.trim().replace(/^["']|["']$/g, "");

// Returns the trigger names of the top-level `on:` key; throws on syntax it cannot read (flow map).
export function onKeys(text) {
  const lines = text.split("\n");
  const i = lines.findIndex((l) => /^["']?on["']?\s*:/.test(l));
  if (i < 0) return null;
  const rest = lines[i].replace(/^["']?on["']?\s*:/, "").replace(/\s+#.*$/, "").trim();
  if (rest.startsWith("{")) throw new Error("unsupported syntax: flow map for 'on:'");
  if (rest.startsWith("[")) return rest.slice(1, rest.indexOf("]")).split(",").map(unq).filter(Boolean);
  if (rest) return [unq(rest)];
  const keys = [];
  let base = -1;
  for (const l of lines.slice(i + 1)) {
    if (/^\s*(#.*)?$/.test(l)) continue;
    const indent = l.match(/^ */)[0].length;
    if (indent === 0) break; // next top-level key ends the block
    if (base < 0) base = indent;
    if (indent !== base) continue; // nested content (branches lists, cron items, ...)
    const m = l.match(/^\s*(?:-\s+)?(?:(["'])(.+?)\1|([A-Za-z_]+))\s*:?\s*(?:#.*)?$/) ?? l.match(/^\s*(?:-\s+)?(?:(["'])(.+?)\1|([A-Za-z_]+))\s*:/);
    if (m) keys.push(m[2] ?? m[3]);
  }
  return keys;
}

export function check(name, text) {
  const m = name.match(/^(.+)\.ya?ml$/);
  if (!m || !name.endsWith(".yaml")) return `${name}: extension must be .yaml`;
  let keys;
  try { keys = onKeys(text); } catch (e) { return `${name}: ${e.message}`; }
  if (!keys?.length) return `${name}: no 'on:' triggers found`;
  // Central group is [a-z0-9]+ on purpose: no '-' or '_' in the group name.
  if (keys.length === 1 && keys[0] === "workflow_call")
    return /^[a-z0-9]+\.[a-z0-9-]+\.yaml$/.test(name) ? null : `${name}: central workflow must be <group>.<action>.yaml`;
  const triggers = [...keys].sort().join(",");
  return new RegExp(`^${triggers}\\.[a-z0-9][a-z0-9.-]*\\.yaml$`).test(name)
    ? null
    : `${name}: caller workflow must be ${triggers}.<action>.yaml (triggers sorted, equal to 'on:' keys)`;
}

export function checkDir(dir) {
  let files = [];
  try { files = readdirSync(dir); } catch { return []; } // no workflows dir: nothing to check
  return files.filter((f) => /\.ya?ml$/.test(f) && statSync(join(dir, f)).isFile()).map((f) => check(f, readFileSync(join(dir, f), "utf8"))).filter(Boolean);
}

function selfTest() {
  const dir = mkdtempSync(join(tmpdir(), "wfnames-"));
  const good = {
    "core.qa.yaml": "on:\n  workflow_call:\nname: x\n",
    "merge_group,pull_request,push.qa.yaml": "on:\n  push:\n    branches: [main]\n  merge_group:\n  pull_request:\n",
    "merge_group,pull_request,push.e2e-v2.3.0.yaml": "on:\n  pull_request:\n  push:\n  merge_group:\n",
    "pull_request,push.branches.yaml": "on:\n  push:\n    branches:\n      - main\n  pull_request:\n",
    "pull_request,schedule.cron.yaml": "on:\n  schedule:\n    - cron: '0 0 * * 1'\n  pull_request:\n",
    "pull_request,push.list.yaml": "on:\n  - push\n  - pull_request\n",
    "pull_request,push.quoted.yaml": "on:\n  \"push\":\n  'pull_request':\n",
    "pull_request,push.indent4.yaml": "name: x\non:\n    push:\n        branches: [a]\n    pull_request:\njobs: {}\n",
    "push.scalar.yaml": "on: push\n",
    "pull_request,push.inline.yaml": "on: [push, pull_request]\n",
    "workflow_dispatch.release.yaml": "name: R\non:\n  workflow_dispatch:\n    inputs:\n      bump:\n        type: string\njobs: {}\n",
  };
  const bad = {
    "qa.yaml": "on:\n  workflow_call:\n",
    "pull_request,push.qa.yaml": "on:\n  push:\n  merge_group:\n  pull_request:\n",
    "push,pull_request.qa.yaml": "on:\n  push:\n  pull_request:\n",
    "push.qa.yml": "on:\n  push:\n",
    "push.flow.yaml": "on: {push: {}}\n",
    "push.nested.yaml": "on:\n  push:\n    branches:\n      - main\n  pull_request:\n",
  };
  mkdirSync(join(dir, "subdir.yaml")); // directories and non-yaml files must be ignored
  writeFileSync(join(dir, "README.md"), "# not a workflow\n");
  for (const [f, t] of Object.entries({ ...good, ...bad })) writeFileSync(join(dir, f), t);
  const errs = checkDir(dir);
  rmSync(dir, { recursive: true });
  const failed = errs.map((e) => e.split(":")[0]).sort();
  const expected = Object.keys(bad).sort();
  if (JSON.stringify(failed) !== JSON.stringify(expected)) {
    console.error("self-test FAILED\n expected:", expected, "\n got:", failed);
    process.exit(1);
  }
  console.log(`self-test OK (${Object.keys(good).length} accepted, ${expected.length} rejected)`);
}

if (process.argv[1] === new URL(import.meta.url).pathname) {
  if (process.argv[2] === "--self-test") selfTest();
  else {
    const errs = checkDir(process.argv[2] ?? ".github/workflows");
    errs.forEach((e) => console.error(e));
    if (errs.length) process.exit(1);
    console.log("workflow names OK");
  }
}
