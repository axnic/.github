#!/usr/bin/env node
/**
 * Computes the version of the next release for the central release.prepare.yaml workflow.
 *
 * Exactly one of BUMP / VERSION must be set (anything else is an error):
 *   BUMP=auto|patch|minor|major  next version from the last stable tag (vX.Y.Z, no prerelease);
 *                                `auto` reads the commits since that tag: a breaking change gives
 *                                major, a feature (`+` / `feat`) minor, anything else patch.
 *   VERSION=X.Y.Z[-pre]          exactly that version (no leading "v"); a prerelease such as
 *                                0.13.0-rc.1 is how a release candidate is cut.
 *
 * Both commit conventions of parseSubject are understood (rtunk's `+![scope]:` and Conventional
 * Commits' `feat(scope)!:`), plus a `BREAKING CHANGE:` / `BREAKING-CHANGE:` footer.
 *
 * Usage (from the repository being released, git history fetched):
 *   BUMP=auto node scripts/release-version.mjs
 * Also fails when HEAD already carries a vX.Y.Z tag (a re-run after the tag push must not cut a
 * second version), when bump=auto finds no commit, when a bump would land below an existing tag
 * (e.g. only v1.0.0-rc.1 exists) and, when DEFAULT_BRANCH is set, when GITHUB_REF is not that branch.
 *
 * Prints `version=`, `tag=`, `prev_tag=`, `prerelease=` lines, also appended to $GITHUB_OUTPUT
 * when set. prev_tag (start of the release-notes range) is the last stable tag for a stable
 * release, the last tag of any kind for a prerelease, `v0.0.0` when the repository has no tag.
 */

import { execFileSync } from "node:child_process";
import { appendFileSync } from "node:fs";
import { fileURLToPath } from "node:url";

import { commitTitle, parseSubject } from "./generate-release-notes.mjs";

const SEMVER = /^(\d+)\.(\d+)\.(\d+)(?:-([0-9A-Za-z.-]+))?$/;

/** Semver order of two versions without "v" (prerelease identifiers compared per semver 2.0). */
export function compareVersions(a, b) {
  const [, ...pa] = a.match(SEMVER);
  const [, ...pb] = b.match(SEMVER);
  for (let i = 0; i < 3; i++) if (+pa[i] !== +pb[i]) return +pa[i] - +pb[i];
  if (!pa[3] || !pb[3]) return (pa[3] ? -1 : 0) - (pb[3] ? -1 : 0);
  const xa = pa[3].split(".");
  const xb = pb[3].split(".");
  for (let i = 0; i < Math.max(xa.length, xb.length); i++) {
    if (xa[i] === undefined) return -1;
    if (xb[i] === undefined) return 1;
    if (xa[i] === xb[i]) continue;
    const na = /^\d+$/.test(xa[i]);
    const nb = /^\d+$/.test(xb[i]);
    if (na && nb) return +xa[i] - +xb[i];
    if (na !== nb) return na ? -1 : 1;
    return xa[i] < xb[i] ? -1 : 1;
  }
  return 0;
}

/** "major" | "minor" | "patch" from the full messages (subject + body) of the commits. */
export function bumpLevel(messages) {
  let level = "patch";
  for (const msg of messages) {
    const [subject, ...body] = msg.split("\n");
    const parsed = parseSubject(commitTitle(subject.trim(), body.join("\n")));
    if (parsed?.breaking || /^BREAKING[ -]CHANGE:/m.test(msg)) return "major";
    if (parsed?.type === "+") level = "minor";
  }
  return level;
}

/**
 * @param {{bump?: string, version?: string, tags: string[], headTags?: string[], ref?: string,
 *   defaultBranch?: string, messages?: () => string[]}} opts
 *   tags: every tag of the repository (non-semver ones are ignored); headTags: the tags on HEAD;
 *   ref/defaultBranch: the dispatched ref and the repository's default branch (checked when
 *   defaultBranch is set); messages: lazily returns the commit messages since the last stable tag
 *   (only called for bump=auto).
 * @returns {{version: string, tag: string, prevTag: string, prerelease: boolean}}
 */
export function nextVersion({ bump = "", version = "", tags, headTags = [], ref = "", defaultBranch = "", messages = () => [] }) {
  if (!bump === !version) throw new Error("set exactly one of the inputs 'bump' and 'version'");
  if (defaultBranch && ref !== `refs/heads/${defaultBranch}`) {
    throw new Error(`releases (release candidates included) are cut from the default branch '${defaultBranch}', not from '${ref}'`);
  }
  const released = headTags.find((t) => t.startsWith("v") && SEMVER.test(t.slice(1)));
  if (released) {
    throw new Error(`HEAD is already released as ${released}: re-run only the failed jobs, or delete the tag to start over`);
  }
  const versions = tags
    .filter((t) => t.startsWith("v") && SEMVER.test(t.slice(1)))
    .map((t) => t.slice(1))
    .sort(compareVersions)
    .reverse();
  const lastStable = versions.find((v) => !v.includes("-")) ?? "0.0.0";
  const lastAny = versions[0] ?? "0.0.0";

  let next;
  if (version) {
    if (!SEMVER.test(version)) throw new Error(`invalid version '${version}' (expected X.Y.Z or X.Y.Z-pre, no leading v)`);
    if (versions.includes(version)) throw new Error(`tag v${version} already exists`);
    next = version;
  } else {
    if (!["auto", "patch", "minor", "major"].includes(bump)) throw new Error(`invalid bump '${bump}' (auto|patch|minor|major)`);
    let level = bump;
    if (bump === "auto") {
      const msgs = messages();
      if (msgs.length === 0) throw new Error(`no commit since v${lastStable}: nothing to release`);
      level = bumpLevel(msgs);
    }
    const [, ma, mi, pa] = lastStable.match(SEMVER).map(Number);
    next = { major: `${ma + 1}.0.0`, minor: `${ma}.${mi + 1}.0`, patch: `${ma}.${mi}.${pa + 1}` }[level];
    if (versions.includes(next)) throw new Error(`tag v${next} already exists`);
    if (compareVersions(next, lastAny) < 0) {
      throw new Error(`bump=${bump} gives v${next}, lower than the existing v${lastAny}: pass 'version' explicitly`);
    }
  }
  const prerelease = next.includes("-");
  return { version: next, tag: `v${next}`, prevTag: `v${prerelease ? lastAny : lastStable}`, prerelease };
}

// ── CLI ──────────────────────────────────────────────────────────────────────────────────────────

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const git = (...args) => execFileSync("git", ["-c", "log.showSignature=false", ...args], { encoding: "utf8" });
  try {
    const tags = git("tag", "-l", "v*").split("\n").filter(Boolean);
    const r = nextVersion({
      bump: process.env.BUMP?.trim(),
      version: process.env.VERSION?.trim(),
      tags,
      headTags: git("tag", "--points-at", "HEAD", "v*").split("\n").filter(Boolean),
      ref: process.env.GITHUB_REF ?? "",
      defaultBranch: process.env.DEFAULT_BRANCH?.trim() ?? "",
      messages: () => {
        const stable = tags.filter((t) => SEMVER.test(t.slice(1)) && !t.includes("-"));
        const last = stable.sort((a, b) => compareVersions(a.slice(1), b.slice(1))).at(-1);
        return git("log", "--format=%B%x1e", last ? `${last}..HEAD` : "HEAD")
          .split("\x1e")
          .map((m) => m.trim())
          .filter(Boolean);
      },
    });
    const out = `version=${r.version}\ntag=${r.tag}\nprev_tag=${r.prevTag}\nprerelease=${r.prerelease}\n`;
    process.stdout.write(out);
    if (process.env.GITHUB_OUTPUT) appendFileSync(process.env.GITHUB_OUTPUT, out);
  } catch (e) {
    console.error(`::error::${e.message}`);
    process.exit(1);
  }
}
