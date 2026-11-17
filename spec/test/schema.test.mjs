import { test } from 'node:test';
import assert from 'node:assert/strict';
import { validateBody } from './helpers.mjs';

test('src accepts IOS and ANDROID', () => {
  for (const src of ['IOS', 'ANDROID']) {
    const r = validateBody({ src, data: [{ event_id: 'e1', event_name: 'app_launched', client_id: 'c1', data: {} }] });
    assert.equal(r.valid, true, `${src}: ${JSON.stringify(r.errors)}`);
  }
});

test('unknown device property name is rejected', () => {
  const body = { src: 'IOS', data: [{ event_id: 'e1', event_name: 'app_launched', client_id: 'c1', data: {},
    device_properties: [{ name: 'sdk_flavor', value: 'x' }] }] };
  assert.equal(validateBody(body).valid, false);
});

test('unknown event field is rejected', () => {
  const body = { src: 'IOS', data: [{ event_id: 'e1', event_name: 'app_launched', client_id: 'c1', data: {}, foo: 1 }] };
  assert.equal(validateBody(body).valid, false);
});

test('named data types are exported for the typed SDK models', async () => {
  const { readFileSync } = await import('node:fs');
  const types = JSON.parse(readFileSync(new URL('../schema/event-data-types.json', import.meta.url), 'utf8'));
  for (const name of ['Cart', 'CartLine', 'Checkout', 'Collection', 'ProductVariant', 'SearchResult', 'Customer',
    'FormElement', 'InputElement', 'CustomValue', 'Money', 'PricingPercentageValue', 'MailingAddress']) {
    assert.equal(types[name]?.type, 'object', name);
  }
  assert.ok(types.$comment.startsWith('exported from data-api'));
});
