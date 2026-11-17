import { test } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { mkdtempSync, mkdirSync, readdirSync, readFileSync, rmSync, statSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, relative } from 'node:path';
import { fileURLToPath } from 'node:url';

const pkgDir = join(dirname(fileURLToPath(import.meta.url)), '..', '..');
const repoRoot = join(pkgDir, '..');
const script = join(pkgDir, 'scripts', 'sync-native.mjs');
const coreDir = join(repoRoot, 'ios', 'Sources', 'AnglerAnalytics');
const vendorDir = join(pkgDir, 'ios', 'vendor', 'AnglerAnalytics');

function tree(dir) {
  const out = [];
  const walk = (d) => {
    for (const name of readdirSync(d)) {
      const p = join(d, name);
      if (statSync(p).isDirectory()) walk(p);
      else out.push(relative(dir, p));
    }
  };
  walk(dir);
  return out.sort();
}

const expected = () => tree(coreDir).filter((f) => f.endsWith('.swift') || f === join('Resources', 'PrivacyInfo.xcprivacy'));

test('copies every Swift file and the privacy manifest into ios/vendor', () => {
  execFileSync('node', [script]);
  assert.deepEqual(tree(vendorDir), expected());
  assert.ok(tree(vendorDir).includes('AnglerCore.swift'));
  for (const f of expected()) {
    assert.equal(readFileSync(join(vendorDir, f), 'utf8'), readFileSync(join(coreDir, f), 'utf8'), f);
  }
});

test('running twice gives the same tree, and deleted sources disappear', () => {
  const tmp = mkdtempSync(join(tmpdir(), 'sync-native-'));
  try {
    const src = join(tmp, 'src');
    const dest = join(tmp, 'dest');
    mkdirSync(join(src, 'Resources'), { recursive: true });
    mkdirSync(join(src, 'Sub'), { recursive: true });
    writeFileSync(join(src, 'A.swift'), 'a');
    writeFileSync(join(src, 'Sub', 'B.swift'), 'b');
    writeFileSync(join(src, 'Resources', 'PrivacyInfo.xcprivacy'), 'p');
    writeFileSync(join(src, 'Notes.md'), 'not copied');
    execFileSync('node', [script, src, dest]);
    const first = tree(dest);
    execFileSync('node', [script, src, dest]);
    assert.deepEqual(tree(dest), first);
    assert.deepEqual(first, ['A.swift', join('Resources', 'PrivacyInfo.xcprivacy'), join('Sub', 'B.swift')]);
    rmSync(join(src, 'Sub', 'B.swift'));
    execFileSync('node', [script, src, dest]);
    assert.deepEqual(tree(dest), ['A.swift', join('Resources', 'PrivacyInfo.xcprivacy')]);
  } finally {
    rmSync(tmp, { recursive: true, force: true });
  }
});

test('npm pack includes the vendored Swift core and excludes tests', () => {
  const out = execFileSync('npm', ['pack', '--dry-run', '--json', '--ignore-scripts=false'], { cwd: pkgDir, encoding: 'utf8' });
  const files = JSON.parse(out.slice(out.indexOf('[')))[0].files.map((f) => f.path);
  assert.ok(files.includes('ios/vendor/AnglerAnalytics/AnglerCore.swift'), 'vendored core missing');
  assert.ok(files.includes('ios/vendor/AnglerAnalytics/Resources/PrivacyInfo.xcprivacy'));
  assert.ok(files.includes('ios/AnglerAnalyticsRN.mm'));
  assert.ok(files.includes('AnglerAnalyticsRN.podspec'));
  assert.ok(files.includes('src/index.ts'));
  assert.ok(!files.some((f) => f.includes('__tests__')), 'tests must not ship');
});
