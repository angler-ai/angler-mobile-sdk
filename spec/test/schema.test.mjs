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
