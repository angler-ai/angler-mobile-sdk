// The typed model shared by the generators: data-api's events schema snapshot (spec/schema/)
// walked into named object types and unions. generate-models.mjs turns it into code for the four
// SDKs; generate-docs.mjs into docs/.
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

export const root = join(dirname(fileURLToPath(import.meta.url)), '..', '..');

const body = JSON.parse(readFileSync(join(root, 'spec/schema/events-post-body.schema.json'), 'utf8'));
const namedTypes = JSON.parse(readFileSync(join(root, 'spec/schema/event-data-types.json'), 'utf8'));
const source = namedTypes.$comment;
delete namedTypes.$comment;

const eventSchema = body.properties.data.items;
const dataSchema = eventSchema.properties.data;
const eventNames = eventSchema.properties.event_name.enum.filter((n) => n !== 'custom_event');

// ---------------------------------------------------------------------------------------------
// Model: walk the data schema, naming each object after data-api's named type when one matches
// (ignoring descriptions), otherwise after its parent and property.

const PREFIX = 'Angler';
const cap = (s) => s[0].toUpperCase() + s.slice(1);
const camel = (snake) => snake.replace(/_([a-z])/g, (_, c) => c.toUpperCase());

function canon(x) {
  if (Array.isArray(x)) return x.map(canon);
  if (x && typeof x === 'object') {
    return Object.fromEntries(
      Object.keys(x)
        .filter((k) => k !== 'description')
        .sort()
        .map((k) => [k, canon(x[k])])
    );
  }
  return x;
}
const key = (x) => JSON.stringify(canon(x));
const exactKey = (x) => JSON.stringify(x);
// A schema identical to a named type (descriptions included) takes that name; failing that, a
// named type with the same shape (e.g. InventoryItem.cost is Money with its own description).
const nameByExact = new Map();
const nameByKey = new Map();
for (const [name, schema] of Object.entries(namedTypes)) {
  if (!nameByExact.has(exactKey(schema))) nameByExact.set(exactKey(schema), name);
  if (!nameByKey.has(key(schema))) nameByKey.set(key(schema), name);
}
const nameFor = (schema) => nameByExact.get(exactKey(schema)) ?? nameByKey.get(key(schema));

/** name → { kind: 'object', name, description, fields } | { kind: 'union', name, members } */
const types = new Map();
const keyOfType = new Map();
/** union member name → union names it belongs to */
const unionsOf = new Map();

function register(name, k, build) {
  let n = name;
  for (let i = 2; types.has(n) && keyOfType.get(n) !== k; i++) n = `${name}${i}`;
  if (!types.has(n)) {
    keyOfType.set(n, k);
    types.set(n, null); // reserve (no recursion in the schema, but stay safe)
    types.set(n, build(n));
  }
  return n;
}

function walk(schema, suggested) {
  if (schema.anyOf) {
    const k = key(schema);
    const name = register(nameFor(schema) ?? suggested, k, (n) => {
      const members = schema.anyOf.map((m, i) => walk(m, `${n}Option${i + 1}`));
      if (!members.every((m) => m.kind === 'object')) throw new Error(`${n}: only unions of objects are supported`);
      for (const m of members) unionsOf.set(m.name, [...(unionsOf.get(m.name) ?? []), n]);
      return { kind: 'union', name: n, members: members.map((m) => m.name) };
    });
    return { kind: 'union', name };
  }
  switch (schema.type) {
    case 'string':
      return { kind: 'string' };
    case 'number':
    case 'integer':
      return { kind: 'number' };
    case 'boolean':
      return { kind: 'bool' };
    case 'array':
      return { kind: 'array', of: walk(schema.items, suggested) };
    case 'object': {
      const k = key(schema);
      const name = register(nameFor(schema) ?? suggested, k, (n) => ({
        kind: 'object',
        name: n,
        description: schema.description,
        fields: Object.entries(schema.properties ?? {}).map(([prop, s]) => ({
          json: prop,
          description: s.description,
          required: (schema.required ?? []).includes(prop),
          type: walk(s, n + cap(prop)),
        })),
      }));
      return { kind: 'object', name };
    }
    default:
      throw new Error(`${suggested}: unsupported schema ${JSON.stringify(schema).slice(0, 120)}`);
  }
}

walk(
  { ...dataSchema, description: "An event's data: the commerce objects it refers to, plus custom name/value pairs." },
  'Data'
);
const objects = [...types.values()].filter((t) => t.kind === 'object');
const unions = [...types.values()].filter((t) => t.kind === 'union');
const T = (name) => PREFIX + name;

export { source, eventNames, objects, unions, unionsOf, types, PREFIX, T, cap, camel };
