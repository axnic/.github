#!/usr/bin/env node
// Checks the naming convention of every file in .github/workflows/:
//   central (on: workflow_call only)  ->  <group>.<action>.yaml
//   caller  (anything else)           ->  <triggers>.<action>.yaml
//       with <triggers> = the `on:` keys, sorted alphabetically, comma separated.
// Usage: node scripts/check-workflow-names.mjs [workflows-dir]   |   --self-test
// ponytail: `on:` parsed with a line scanner (block map, inline list, scalar); no YAML dep. Use a parser if flow maps appear.
import { mkdtempSync, mkdirSync, readdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

export function onKeys(text) {
  const lines = text.split("\n");
  const i = lines.findIndex((l) => /^["']?on["']?:/.test(l));
  if (i < 0) return null;
  const rest = lines[i].replace(/^["']?on["']?:/, "").replace(/\s+#.*$/, "").trim();
  if (rest.startsWith("[")) return rest.slice(1, rest.indexOf("]")).split(",").map((s) => s.trim()).filter(Boolean);
  if (rest) return [rest];
  const keys = [];
  for (const l of lines.slice(i + 1)) {
    if (/^\s*(#.*)?$/.test(l)) continue;
    const m = l.match(/^( +)([A-Za-z_]+):/);
    if (!m) break; // dedent to next top-level key
    if (m[1].length === 2) keys.push(m[2]);
  }
  return keys;
}

export function check(name, text) {
  const m = name.match(/^(.+)\.ya?ml$/);
  if (!m || !name.endsWith(".yaml")) return `${name}: extension must be .yaml`;
  const keys = onKeys(text);
  if (!keys?.length) return `${name}: no 'on:' triggers found`;
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
  return files.map((f) => check(f, readFileSync(join(dir, f), "utf8"))).filter(Boolean);
}

function selfTest() {
  const dir = mkdtempSync(join(tmpdir(), "wfnames-"));
  const good = {
    "core.qa.yaml": "on:\n  workflow_call:\nname: x\n",
    "merge_group,pull_request,push.qa.yaml": "on:\n  push:\n    branches: [main]\n  merge_group:\n  pull_request:\n",
    "merge_group,pull_request,push.e2e-v2.3.0.yaml": "on:\n  pull_request:\n  push:\n  merge_group:\n",
    "workflow_dispatch.release.yaml": "name: R\non:\n  workflow_dispatch:\n    inputs:\n      bump:\n        type: string\njobs: {}\n",
  };
  const bad = {
    "qa.yaml": "on:\n  workflow_call:\n",
    "pull_request,push.qa.yaml": "on:\n  push:\n  merge_group:\n  pull_request:\n",
    "push,pull_request.qa.yaml": "on:\n  push:\n  pull_request:\n",
    "push.qa.yml": "on:\n  push:\n",
  };
  mkdirSync(dir, { recursive: true });
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
