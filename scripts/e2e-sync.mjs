#!/usr/bin/env node
// Core of e2e.sync.yaml: given the versions printed by `mise run ci:e2e:versions` (stdin, one per line),
// creates the missing `merge_group,pull_request,push.e2e-<version>.yaml` callers from the template and adds one
// README badge row per new version. Prints the new versions (one per line) on stdout; nothing new = no output.
// Usage: node scripts/e2e-sync.mjs --workflows <dir> --template <file> [--readme <file>] < versions
// ponytail: a new row copies the LAST existing e2e badge row with its version swapped (format auto-detected, appended
// after it, no sorting); no e2e badge row in the README = README untouched.
import { existsSync, readdirSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { fileURLToPath } from "node:url";

const PREFIX = "merge_group,pull_request,push.e2e-";
const VERSION = /^[A-Za-z0-9._-]+$/; // versions end up in file names, git ref names and sed-free text

export function parseVersions(text) {
  const out = [...new Set(text.split("\n").map((l) => l.trim()).filter(Boolean))];
  for (const v of out) if (!VERSION.test(v)) throw new Error(`invalid version ${JSON.stringify(v)}: must match ${VERSION}`);
  return out;
}

export const existingVersions = (dir) =>
  readdirSync(dir).filter((f) => f.startsWith(PREFIX) && f.endsWith(".yaml")).map((f) => f.slice(PREFIX.length, -".yaml".length));

const esc = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
const isBadgeRow = (l) => l.startsWith("|") && l.includes(PREFIX.replaceAll(",", "%2C")) && /\.yaml/.test(l);

// New row = the last e2e badge row with its version swapped: in `e2e-<old>.yaml` and in every standalone <old> token.
export function insertRows(readme, versions) {
  if (!versions.length) return readme;
  const lines = readme.split("\n");
  const last = lines.findLastIndex(isBadgeRow);
  if (last < 0) return readme;
  const old = lines[last].match(/push\.e2e-(.+?)\.yaml/)?.[1];
  if (!old) return readme;
  const re = new RegExp(`e2e-${esc(old)}(?=\\.yaml)|(?<![A-Za-z0-9._-])${esc(old)}(?![A-Za-z0-9_-]|\\.[0-9])`, "g");
  const rows = versions.map((v) => lines[last].replace(re, (m) => (m.startsWith("e2e-") ? `e2e-${v}` : v)));
  lines.splice(last + 1, 0, ...rows);
  return lines.join("\n");
}

export function sync({ workflows, template, readme, versions }) {
  const have = new Set(existingVersions(workflows));
  const fresh = versions.filter((v) => !have.has(v));
  const tmpl = readFileSync(template, "utf8");
  for (const v of fresh) writeFileSync(join(workflows, `${PREFIX}${v}.yaml`), tmpl.replaceAll("__VERSION__", v));
  if (fresh.length && readme && existsSync(readme)) writeFileSync(readme, insertRows(readFileSync(readme, "utf8"), fresh));
  return fresh;
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const a = process.argv.slice(2);
  const opt = (n) => a[a.indexOf(n) + 1];
  try {
    const fresh = sync({ workflows: opt("--workflows"), template: opt("--template"), readme: opt("--readme"), versions: parseVersions(readFileSync(0, "utf8")) });
    if (fresh.length) console.log(fresh.join("\n"));
  } catch (e) {
    console.error(`e2e-sync: ${e.message}`);
    process.exit(1);
  }
}
