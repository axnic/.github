// Run with `node --test scripts/` (or `mise run ci:scripts`); no dependency beyond Node.
import assert from "node:assert/strict";
import { execFileSync, spawnSync } from "node:child_process";
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { test } from "node:test";
import { fileURLToPath } from "node:url";

import { bumpLevel, compareVersions, nextVersion } from "./release-version.mjs";

const TAGS = ["v0.12.0", "v0.13.0-rc.1", "v0.13.0-rc.2", "v0.12.1", "sdk/go/pulumi-x/v0.12.1", "nightly"];

test("exactly one of bump and version", () => {
  assert.throws(() => nextVersion({ tags: TAGS }), /exactly one/);
  assert.throws(() => nextVersion({ bump: "patch", version: "1.0.0", tags: TAGS }), /exactly one/);
  assert.throws(() => nextVersion({ bump: "rc-patch", tags: TAGS }), /invalid bump/);
  assert.throws(() => nextVersion({ version: "v1.0.0", tags: TAGS }), /invalid version/);
  assert.throws(() => nextVersion({ version: "0.13.0-rc.2", tags: TAGS }), /already exists/);
});

test("explicit bumps start from the last stable tag", () => {
  assert.deepEqual(nextVersion({ bump: "minor", tags: TAGS }), {
    version: "0.13.0",
    tag: "v0.13.0",
    prevTag: "v0.12.1",
    prerelease: false,
  });
  assert.equal(nextVersion({ bump: "patch", tags: ["v0.12.1"] }).version, "0.12.2");
  assert.equal(nextVersion({ bump: "major", tags: TAGS }).version, "1.0.0");
  assert.deepEqual(nextVersion({ bump: "minor", tags: [] }), {
    version: "0.1.0",
    tag: "v0.1.0",
    prevTag: "v0.0.0",
    prerelease: false,
  });
});

test("an explicit prerelease takes its notes from the last tag of any kind", () => {
  assert.deepEqual(nextVersion({ version: "0.13.0-rc.3", tags: TAGS }), {
    version: "0.13.0-rc.3",
    tag: "v0.13.0-rc.3",
    prevTag: "v0.13.0-rc.2",
    prerelease: true,
  });
  assert.equal(nextVersion({ version: "0.13.0", tags: TAGS }).prevTag, "v0.12.1");
});

test("auto bump, rtunk symbol convention", () => {
  assert.equal(bumpLevel(["![cli]: Fix a crash (#3)", "^[deps]: Bump x", "Merge branch 'main'"]), "patch");
  assert.equal(bumpLevel(["![cli]: Fix a crash", "+[check]: Add --from"]), "minor");
  assert.equal(bumpLevel(["+[check]: Add --from", "-![config]: Remove the old key"]), "major");
  assert.equal(bumpLevel(["~![engine]: Change the default"]), "major");
  assert.equal(bumpLevel([]), "patch");
});

test("auto bump, Conventional Commits", () => {
  assert.equal(bumpLevel(["fix(provider): Fix import", "build(deps): Bump x", "Merge pull request #2 from a/b"]), "patch");
  assert.equal(bumpLevel(["docs: Typo", "feat(bucket): Add quotas"]), "minor");
  assert.equal(bumpLevel(["feat(bucket)!: Rename the alias input"]), "major");
  assert.equal(bumpLevel(["refactor!: Drop v1"]), "major");
  assert.equal(bumpLevel(["fix(key): Rotate\n\nBREAKING CHANGE: the key format changed"]), "major");
  assert.equal(bumpLevel(["fix(key): Rotate\n\nBREAKING-CHANGE: the key format changed"]), "major");
});

test("auto bump through nextVersion only reads the commits when asked", () => {
  let called = 0;
  const messages = () => (called++, ["feat(x): Y"]);
  assert.equal(nextVersion({ bump: "auto", tags: TAGS, messages }).version, "0.13.0");
  assert.equal(nextVersion({ bump: "major", tags: TAGS, messages }).version, "1.0.0");
  assert.equal(called, 1);
});

test("compareVersions follows semver precedence", () => {
  const sorted = ["1.0.0", "1.0.0-rc.10", "1.0.0-alpha", "1.0.0-rc.2", "0.9.9", "1.0.0-alpha.1"].sort(compareVersions);
  assert.deepEqual(sorted, ["0.9.9", "1.0.0-alpha", "1.0.0-alpha.1", "1.0.0-rc.2", "1.0.0-rc.10", "1.0.0"]);
});

test("a bump never lands below an existing tag (e.g. only release candidates so far)", () => {
  assert.throws(() => nextVersion({ bump: "minor", tags: ["v1.0.0-rc.1"] }), /v0\.1\.0, lower than the existing v1\.0\.0-rc\.1/);
  assert.throws(() => nextVersion({ bump: "patch", tags: TAGS }), /lower than the existing v0\.13\.0-rc\.2/);
  assert.equal(nextVersion({ bump: "major", tags: ["v1.0.0-rc.1"] }).version, "1.0.0");
  assert.equal(nextVersion({ version: "1.0.0", tags: ["v1.0.0-rc.1"] }).prevTag, "v0.0.0");
});

test("bump=auto with no commit since the last stable tag fails", () => {
  assert.throws(() => nextVersion({ bump: "auto", tags: TAGS, messages: () => [] }), /no commit since v0\.12\.1/);
});

test("HEAD already released, or not the default branch, fails", () => {
  assert.throws(
    () => nextVersion({ bump: "patch", tags: ["v1.0.0"], headTags: ["v1.0.0"] }),
    /HEAD is already released as v1\.0\.0: re-run only the failed jobs, or delete the tag to start over/,
  );
  assert.equal(nextVersion({ bump: "patch", tags: ["v1.0.0"], headTags: ["nightly"] }).version, "1.0.1");
  const branch = { bump: "patch", tags: [], defaultBranch: "main" };
  assert.throws(() => nextVersion({ ...branch, ref: "refs/heads/feat/x" }), /default branch 'main', not from 'refs\/heads\/feat\/x'/);
  assert.throws(() => nextVersion({ ...branch, ref: "refs/tags/v1.0.0" }), /default branch/);
  assert.equal(nextVersion({ ...branch, ref: "refs/heads/main" }).version, "0.0.1");
});

test("auto bump reads a merge commit through its body (the PR title)", () => {
  assert.equal(bumpLevel(["Merge pull request #5 from a/b\n\nfeat(x)!: Rename"]), "major");
  assert.equal(bumpLevel(["Merge pull request #6 from a/b\n\nfeat(x): Add"]), "minor");
});

test("CLI against a real git repository: re-run after the tag push is refused", () => {
  const dir = mkdtempSync(join(tmpdir(), "release-version-"));
  const cli = fileURLToPath(new URL("./release-version.mjs", import.meta.url));
  const git = (...a) =>
    execFileSync("git", ["-c", "user.name=t", "-c", "user.email=t@t", "-c", "commit.gpgsign=false", "-c", "tag.gpgsign=false", ...a], {
      cwd: dir,
    });
  const run = (env) =>
    spawnSync("node", [cli], { cwd: dir, encoding: "utf8", env: { PATH: process.env.PATH, HOME: process.env.HOME, ...env } });
  try {
    git("init", "-q");
    git("commit", "-q", "--allow-empty", "-m", "fix(a): One");
    git("tag", "-a", "v1.0.0", "-m", "v1.0.0");
    git("commit", "-q", "--allow-empty", "-m", "feat(a): Two");

    const first = run({ BUMP: "auto" });
    assert.equal(first.status, 0, first.stderr);
    assert.match(first.stdout, /^version=1\.1\.0\ntag=v1\.1\.0\nprev_tag=v1\.0\.0\nprerelease=false\n$/);

    git("tag", "-a", "v1.1.0", "-m", "v1.1.0"); // what the workflow pushes, then a job fails
    const rerun = run({ BUMP: "auto" });
    assert.equal(rerun.status, 1);
    assert.match(rerun.stderr, /HEAD is already released as v1\.1\.0/);

    git("commit", "-q", "--allow-empty", "-m", "fix(a): Three");
    assert.match(run({ BUMP: "auto", GITHUB_REF: "refs/heads/dev", DEFAULT_BRANCH: "main" }).stderr, /default branch 'main'/);
    assert.match(run({ BUMP: "auto", GITHUB_REF: "refs/heads/main", DEFAULT_BRANCH: "main" }).stdout, /^version=1\.1\.1\n/);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});
