// Copies the repo's VERSION into every platform's version file, so all four SDKs share one
// version. With --check, writes nothing: lists files that don't match and exits 1.
//
// Usage: node scripts/sync-version.mjs [--check] [--root <dir>]
import { existsSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const args = process.argv.slice(2);
const check = args.includes('--check');
const rootFlag = args.indexOf('--root');
const root = rootFlag >= 0 ? resolve(args[rootFlag + 1]) : join(dirname(fileURLToPath(import.meta.url)), '..');

// Plain semver (SPM resolves only plain semver tags): 1.2.3 or 1.2.3-rc.1.
const SEMVER = /^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$/;

// Each target: a regex whose group 1 is the text before the version and group 3 the text after.
// Only the version is replaced, so JSON and YAML formatting is left alone.
const TARGETS = [
  { path: 'ios/Sources/AnglerAnalytics/Version.swift', re: /(static let current = ")([^"]*)(")/ },
  { path: 'android/gradle.properties', re: /(^VERSION_NAME=)(.*)($)/m },
  {
    path: 'android/angler-analytics/src/main/kotlin/ai/getangler/analytics/SdkVersion.kt',
    re: /(const val CURRENT(?:\s*:\s*String)?\s*=\s*")([^"]*)(")/,
  },
  // The first "version" key in package.json is the top-level one.
  { path: 'react-native/package.json', re: /(^\s*"version"\s*:\s*")([^"]*)(")/m },
  { path: 'flutter/pubspec.yaml', re: /(^version:[ \t]*)(\S+)()/m },
];

const versionFile = join(root, 'VERSION');
if (!existsSync(versionFile)) {
  console.error(`sync-version: ${versionFile} not found`);
  process.exit(2);
}
const version = readFileSync(versionFile, 'utf8').trim();
if (!SEMVER.test(version)) {
  console.error(`sync-version: VERSION "${version}" is not plain semver (e.g. 1.2.3 or 1.2.3-rc.1)`);
  process.exit(2);
}

const mismatched = [];
for (const { path, re } of TARGETS) {
  const file = join(root, path);
  if (!existsSync(file)) {
    console.error(`sync-version: ${path} not found`);
    process.exit(2);
  }
  const text = readFileSync(file, 'utf8');
  const match = text.match(re);
  if (!match) {
    console.error(`sync-version: no version found in ${path}`);
    process.exit(2);
  }
  if (match[2] === version) continue;
  if (check) {
    mismatched.push(`${path}: ${match[2]} (VERSION is ${version})`);
  } else {
    writeFileSync(file, text.replace(re, (_, before, _old, after) => `${before}${version}${after}`));
    console.log(`sync-version: ${path} ${match[2]} → ${version}`);
  }
}

// Install snippets in the docs. Every occurrence is updated; a missing file is skipped.
// SITE is the public docs page, synced to the docs site by .github/workflows/sync-docs.yml.
const SITE = 'site/mobile-sdk.md';
const DOCS = [
  { paths: ['README.md', 'android/README.md', SITE], re: /(ai\.getangler:analytics:)([0-9A-Za-z.+-]+)()/g },
  { paths: ['README.md', 'ios/README.md', SITE], re: /(angler-mobile-sdk(?:\.git)?", exact: ")([^"]+)(")/g },
  { paths: ['README.md', 'flutter/README.md', SITE], re: /(angler_analytics: \^)([0-9A-Za-z.+-]+)()/g },
  // npm installs pin the version: prereleases publish under the `next` tag, not `latest`.
  { paths: ['README.md', 'react-native/README.md', SITE], re: /(npm install @anglerai\/react-native-analytics@)([0-9A-Za-z.+-]+)()/g },
];
for (const { paths, re } of DOCS) {
  for (const path of paths) {
    const file = join(root, path);
    if (!existsSync(file)) continue;
    const text = readFileSync(file, 'utf8');
    const stale = [...text.matchAll(re)].filter((m) => m[2] !== version).map((m) => m[2]);
    if (stale.length === 0) continue;
    if (check) {
      mismatched.push(`${path}: ${stale[0]} (VERSION is ${version})`);
    } else {
      writeFileSync(file, text.replace(re, (_, before, _old, after) => `${before}${version}${after}`));
      console.log(`sync-version: ${path} ${stale[0]} → ${version}`);
    }
  }
}

if (check) {
  if (mismatched.length > 0) {
    console.error(`sync-version: these files don't match VERSION:\n  ${mismatched.join('\n  ')}`);
    console.error('Run `node scripts/sync-version.mjs` and commit the result.');
    process.exit(1);
  }
  console.log(`sync-version: all files at ${version}`);
}
