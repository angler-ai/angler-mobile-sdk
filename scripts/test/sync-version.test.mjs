import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const script = join(dirname(fileURLToPath(import.meta.url)), '..', 'sync-version.mjs');

const FILES = {
  'ios/Sources/AnglerAnalytics/Version.swift': (v) =>
    `enum SDKVersion {\n    /// Written by sync-version.\n    static let current = "${v}"\n}\n`,
  'android/gradle.properties': (v) => `GROUP=ai.getangler\nVERSION_NAME=${v}\nPOM_ARTIFACT_ID=analytics\n`,
  'android/angler-analytics/src/main/kotlin/ai/getangler/analytics/SdkVersion.kt': (v) =>
    `package ai.getangler.analytics\n\ninternal object SdkVersion {\n    const val CURRENT: String = "${v}"\n}\n`,
  'react-native/package.json': (v) =>
    `{\n  "name": "@anglerai/react-native-analytics",\n  "version": "${v}",\n  "devDependencies": {\n    "jest": "^29.7.0"\n  }\n}\n`,
  'flutter/pubspec.yaml': (v) => `name: angler_analytics\ndescription: x\nversion: ${v}\n\nenvironment:\n  sdk: ">=3.5.0 <4.0.0"\n`,
};

function makeTree(version, overrides = {}) {
  const root = mkdtempSync(join(tmpdir(), 'sync-version-'));
  writeFileSync(join(root, 'VERSION'), `${version}\n`);
  for (const [path, render] of Object.entries(FILES)) {
    mkdirSync(dirname(join(root, path)), { recursive: true });
    writeFileSync(join(root, path), render(overrides[path] ?? '0.1.0'));
  }
  return root;
}

const run = (root, ...args) => spawnSync('node', [script, '--root', root, ...args], { encoding: 'utf8' });

test('sync writes VERSION into all five files without reformatting them', () => {
  const root = makeTree('1.2.3');
  try {
    const r = run(root);
    assert.equal(r.status, 0, r.stderr);
    for (const [path, render] of Object.entries(FILES)) {
      assert.equal(readFileSync(join(root, path), 'utf8'), render('1.2.3'), path);
    }
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test('--check exits 1 and names the one file that differs', () => {
  const root = makeTree('0.1.0', { 'flutter/pubspec.yaml': '0.0.9' });
  try {
    const r = run(root, '--check');
    assert.equal(r.status, 1);
    const out = r.stdout + r.stderr;
    assert.match(out, /flutter\/pubspec\.yaml/);
    assert.doesNotMatch(out, /react-native\/package\.json/);
    assert.equal(readFileSync(join(root, 'flutter/pubspec.yaml'), 'utf8'), FILES['flutter/pubspec.yaml']('0.0.9'), '--check writes nothing');
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test('--check exits 0 after a sync', () => {
  const root = makeTree('2.0.0-rc.1');
  try {
    assert.equal(run(root).status, 0);
    const r = run(root, '--check');
    assert.equal(r.status, 0, r.stdout + r.stderr);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test('an invalid VERSION is rejected', () => {
  const root = makeTree('v1.2');
  try {
    assert.notEqual(run(root).status, 0);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test('updates every install snippet in the READMEs, and --check flags a stale one', () => {
  const root = makeTree('2.0.0-rc.1');
  const readme = (v) =>
    `implementation("ai.getangler:analytics:${v}")\n.package(url: "https://github.com/angler-ai/angler-mobile-sdk", exact: "${v}")\nangler_analytics: ^${v}\n`;
  try {
    for (const path of Object.keys(FILES)) writeFileSync(join(root, path), FILES[path]('2.0.0-rc.1'));
    writeFileSync(join(root, 'README.md'), readme('0.1.0') + readme('0.1.0'));
    let r = run(root, '--check');
    assert.equal(r.status, 1);
    assert.match(r.stdout + r.stderr, /README\.md: 0\.1\.0/);
    r = run(root);
    assert.equal(r.status, 0, r.stderr);
    assert.equal(readFileSync(join(root, 'README.md'), 'utf8'), readme('2.0.0-rc.1') + readme('2.0.0-rc.1'));
    assert.equal(run(root, '--check').status, 0);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});
