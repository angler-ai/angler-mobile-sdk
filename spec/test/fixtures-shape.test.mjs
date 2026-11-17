import { test } from 'node:test';
import assert from 'node:assert/strict';
import { CLICK_ID_NAMES, loadFixture } from './helpers.mjs';

function assertUniqueSnakeNames(cases) {
  assert.ok(cases.length > 0);
  assert.equal(new Set(cases.map(c => c.name)).size, cases.length, 'case names must be unique');
  for (const c of cases) assert.match(c.name, /^[a-z0-9]+(_[a-z0-9]+)*$/, c.name);
}

for (const file of ['deeplinks', 'install-referrer']) {
  test(`${file} cases are well-formed`, () => {
    const { cases } = loadFixture(file);
    assertUniqueSnakeNames(cases);
    for (const c of cases) {
      assert.equal(typeof c.input, 'string');
      for (const k of Object.keys(c.expected)) assert.ok(CLICK_ID_NAMES.includes(k), `${c.name}: ${k}`);
    }
  });
}
