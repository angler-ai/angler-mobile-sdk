import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import Ajv from 'ajv';
import { loadFixture } from './helpers.mjs';

// Each platform builds these with its typed models (AnglerData, AnglerCartLine, …) and must
// produce exactly `expected`, which must be a `data` object data-api accepts.
const REQUIRED = ['cart_line_added', 'checkout_with_discounts', 'search_and_custom_data', 'form_submitted'];

const body = JSON.parse(readFileSync(new URL('../schema/events-post-body.schema.json', import.meta.url), 'utf8'));
const validateData = new Ajv({ allErrors: true, strict: false }).compile(body.properties.data.items.properties.data);

test('typed-data cases are valid data objects', () => {
  const { cases } = loadFixture('typed-data');
  assert.deepEqual(cases.map((c) => c.name).sort(), [...REQUIRED].sort());
  for (const c of cases) {
    assert.equal(validateData(c.expected), true, `${c.name}: ${JSON.stringify(validateData.errors)}`);
  }
});
