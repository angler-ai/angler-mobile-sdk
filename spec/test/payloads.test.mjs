import { test } from 'node:test';
import assert from 'node:assert/strict';
import { loadFixture, validateBody } from './helpers.mjs';

const REQUIRED = [
  'standard_event_minimal',
  'custom_event',
  'properties_to_custom_data',
  'disallowed_data_key_dropped',
  'full_attribution_ios',
  'android_gaid',
  'client_id_override',
  'caller_event_id',
  'empty_identifier_values_omitted',
  'android_install_referrer',
  'unknown_device_property_dropped',
];

test('every expected payload is accepted by data-api schema', () => {
  for (const c of loadFixture('payloads').cases) {
    const src = c.input.identity.adIdName === 'gaid' ? 'ANDROID' : 'IOS';
    const r = validateBody({ src, data: [c.expected] });
    assert.equal(r.valid, true, `${c.name}: ${JSON.stringify(r.errors)}`);
  }
});

test('payload case names cover the required set', () => {
  const names = loadFixture('payloads').cases.map(c => c.name);
  assert.equal(new Set(names).size, names.length, 'case names must be unique');
  for (const n of REQUIRED) assert.ok(names.includes(n), n);
});
