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

const DECISIONS = ['remove', 'isolate', 'drop', 'split', 'pause', 'retry'];

test('response-policy cases are well-formed', () => {
  const { cases } = loadFixture('response-policy');
  assertUniqueSnakeNames(cases);
  for (const c of cases) {
    assert.ok(c.input.status === null || Number.isInteger(c.input.status), c.name);
    assert.ok(Number.isInteger(c.input.batchSize) && c.input.batchSize >= 1, c.name);
    assert.ok(DECISIONS.includes(c.expected), `${c.name}: ${c.expected}`);
  }
});

test('backoff cases match the formula', () => {
  const { cases } = loadFixture('backoff');
  assertUniqueSnakeNames(cases);
  for (const c of cases) {
    const { attempt, r } = c.input;
    const want = Math.min(300, 2 ** (attempt - 1)) * (0.5 + 0.5 * r);
    assert.ok(Math.abs(c.expected - want) < 1e-9, `${c.name}: ${c.expected} != ${want}`);
  }
});
