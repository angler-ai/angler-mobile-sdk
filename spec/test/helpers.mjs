import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import Ajv from 'ajv';

const specDir = join(dirname(fileURLToPath(import.meta.url)), '..');

export const CLICK_ID_NAMES = ['gclid', 'gbraid', 'wbraid', 'gad_source', 'fbclid', 'ttclid', 'sccid', 'rdt_cid', 'epik'];

export function loadFixture(name) {
  return JSON.parse(readFileSync(join(specDir, 'fixtures', `${name}.json`), 'utf8'));
}

let validator;
export function validateBody(body) {
  if (!validator) {
    const schema = JSON.parse(readFileSync(join(specDir, 'schema', 'events-post-body.schema.json'), 'utf8'));
    validator = new Ajv({ allErrors: true, strict: false }).compile(schema);
  }
  const valid = validator(body);
  return { valid, errors: valid ? [] : validator.errors };
}
