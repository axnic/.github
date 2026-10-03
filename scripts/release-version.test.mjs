// Run with `node --test scripts/` (or `mise run ci:scripts`); no dependency beyond Node.
import assert from "node:assert/strict";
import { test } from "node:test";

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
  assert.deepEqual(nextVersion({ bump: "patch", tags: TAGS }), {
    version: "0.12.2",
    tag: "v0.12.2",
    prevTag: "v0.12.1",
    prerelease: false,
  });
  assert.equal(nextVersion({ bump: "minor", tags: TAGS }).version, "0.13.0");
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
  assert.equal(nextVersion({ bump: "patch", tags: TAGS, messages }).version, "0.12.2");
  assert.equal(called, 1);
});

test("compareVersions follows semver precedence", () => {
  const sorted = ["1.0.0", "1.0.0-rc.10", "1.0.0-alpha", "1.0.0-rc.2", "0.9.9", "1.0.0-alpha.1"].sort(compareVersions);
  assert.deepEqual(sorted, ["0.9.9", "1.0.0-alpha", "1.0.0-alpha.1", "1.0.0-rc.2", "1.0.0-rc.10", "1.0.0"]);
});
