// Run with `node --test scripts/` (or `mise run ci:scripts`); no dependency beyond Node.
import assert from "node:assert/strict";
import { cpSync, existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { test } from "node:test";
import { fileURLToPath } from "node:url";

import { insertRows, parseVersions, sync } from "./e2e-sync.mjs";

const TEMPLATE = fileURLToPath(new URL("../.github/templates/e2e-caller.yaml.tmpl", import.meta.url));
const rowFor = (v, repo = "pulumi-garage") => {
  const u = `https://github.com/axnic/${repo}/actions/workflows/merge_group%2Cpull_request%2Cpush.e2e-${v}.yaml`;
  return `| ${v} | [![E2E (Garage ${v})](${u}/badge.svg?branch=main)](${u}) |`;
};
const README = (vs) => `# x\n\n| Garage version | Status |\n|---|---|\n${vs.map((v) => rowFor(v)).join("\n")}\n\nAfter.\n`;

test("versions are validated", () => {
  assert.deepEqual(parseVersions("v2.3.0\n\n v2 \nv2\n"), ["v2.3.0", "v2"]);
  for (const bad of ["v1/../x", "a b", "v1;rm", "$(x)", "v1\"", "../v"]) assert.throws(() => parseVersions(bad), /invalid version/);
});

test("row is the last row with the version swapped, appended after it", () => {
  const out = insertRows(README(["v2.2.0", "v2.3.0"]), ["v2.4.0", "v2.5.0"]);
  assert.equal(out, README(["v2.2.0", "v2.3.0", "v2.4.0", "v2.5.0"]));
});

test("short version tokens (v2) are swapped without touching other text", () => {
  const out = insertRows(README(["v2"]), ["v3"]);
  assert.equal(out, README(["v2", "v3"]));
});

test("no e2e table: README unchanged", () => {
  const r = "# x\n\n| a | b |\n|---|---|\n| 1 | 2 |\n";
  assert.equal(insertRows(r, ["v1"]), r);
});

test("sync: creates only missing callers, adds rows, is idempotent", () => {
  const dir = mkdtempSync(join(tmpdir(), "e2esync-"));
  try {
    const wf = join(dir, "wf");
    mkdirSync(wf);
    for (const v of ["v2.2.0", "v2.3.0"]) cpSync(TEMPLATE, join(wf, `merge_group,pull_request,push.e2e-${v}.yaml`));
    writeFileSync(join(wf, "unrelated.yaml"), "x");
    const readme = join(dir, "README.md");
    writeFileSync(readme, README(["v2.2.0", "v2.3.0"]));
    const args = { workflows: wf, template: TEMPLATE, readme };

    assert.deepEqual(sync({ ...args, versions: ["v2.2.0", "v2.3.0", "v2.4.0"] }), ["v2.4.0"]);
    const created = readFileSync(join(wf, "merge_group,pull_request,push.e2e-v2.4.0.yaml"), "utf8");
    assert.equal(created, readFileSync(TEMPLATE, "utf8").replaceAll("__VERSION__", "v2.4.0"));
    assert.ok(!created.includes("__VERSION__"));
    assert.equal(readFileSync(readme, "utf8"), README(["v2.2.0", "v2.3.0", "v2.4.0"]));

    assert.deepEqual(sync({ ...args, versions: ["v2.2.0", "v2.3.0", "v2.4.0"] }), []); // nothing new: untouched
    assert.equal(readFileSync(readme, "utf8"), README(["v2.2.0", "v2.3.0", "v2.4.0"]));
    assert.ok(!existsSync(join(wf, "merge_group,pull_request,push.e2e-v2.5.0.yaml")));
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test("single-row table, CRLF endings and unsorted rows", () => {
  assert.equal(insertRows(README(["v2.3.0"]), ["v2.4.0"]), README(["v2.3.0", "v2.4.0"]));
  const crlf = (s) => s.replaceAll("\n", "\r\n");
  assert.equal(insertRows(crlf(README(["v2.2.0", "v2.3.0"])), ["v2.4.0"]), crlf(README(["v2.2.0", "v2.3.0", "v2.4.0"])));
  // appended after the LAST row, wherever it sorts
  assert.equal(insertRows(README(["v2.3.0", "v2.1.0"]), ["v2.4.0"]), README(["v2.3.0", "v2.1.0", "v2.4.0"]));
});
