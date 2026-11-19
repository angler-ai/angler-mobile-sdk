// Generates docs/: a page per data object type (fields, where it's used, and an example in Swift,
// Kotlin, TypeScript, Dart and JSON) plus an index, from the schema snapshot and the hand-written
// examples and notes in scripts/docs-content.mjs. Never hand-edit the outputs.
//
// Usage: node scripts/generate-docs.mjs [--check]
//   --check  writes nothing; exits 1 if any page is out of date or a stale page exists.
import { mkdirSync, readdirSync, readFileSync, rmSync, writeFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';
import { pathToFileURL } from 'node:url';
import { root, eventNames, objects, unions, T, cap, camel } from './lib/model.mjs';
import { dataFields, unionExamples, typeNotes, fieldNotes, eventOrder, propertiesExample } from './docs-content.mjs';

// ---------------------------------------------------------------------------------------------
// Model helpers

const objectByName = new Map(objects.map((o) => [o.name, o]));
const unionByName = new Map(unions.map((u) => [u.name, u]));
const kebab = (name) => name.replace(/([a-z0-9])([A-Z])/g, '$1-$2').toLowerCase();
const lowerFirst = (s) => s[0].toLowerCase() + s.slice(1);
const pageOf = (name) => `${kebab(name)}/README.md`;
const isStandard = (event) => eventNames.includes(event);

/** The union member an example value is, by its keys. */
function memberFor(union, value) {
  const fits = union.members.filter((m) => {
    const names = new Set(objectByName.get(m).fields.map((f) => f.json));
    return Object.keys(value).every((k) => names.has(k));
  });
  if (fits.length !== 1) throw new Error(`${union.name}: can't tell which member ${JSON.stringify(value)} is`);
  return fits[0];
}

/** Throws unless value is valid JSON for type t (no unknown keys, required fields present). */
function validate(t, value, path) {
  const fail = (why) => {
    throw new Error(`docs-content: ${path}: ${why}`);
  };
  switch (t.kind) {
    case 'string':
      if (typeof value !== 'string') fail('expected a string');
      return;
    case 'number':
      if (typeof value !== 'number') fail('expected a number');
      return;
    case 'bool':
      if (typeof value !== 'boolean') fail('expected a boolean');
      return;
    case 'array':
      if (!Array.isArray(value) || value.length === 0) fail('expected a non-empty array');
      value.forEach((v, i) => validate(t.of, v, `${path}[${i}]`));
      return;
    case 'union':
      return validate({ kind: 'object', name: memberFor(unionByName.get(t.name), value) }, value, path);
    case 'object': {
      if (!value || typeof value !== 'object' || Array.isArray(value)) fail('expected an object');
      const o = objectByName.get(t.name);
      for (const k of Object.keys(value)) if (!o.fields.some((f) => f.json === k)) fail(`${T(o.name)} has no field ${k}`);
      for (const f of o.fields) {
        if (f.required && !(f.json in value)) fail(`${T(o.name)}.${f.json} is required`);
        if (f.json in value) validate(f.type, value[f.json], `${path}.${f.json}`);
      }
      return;
    }
  }
}

// ---------------------------------------------------------------------------------------------
// Examples: every data object's example is validated, then each type's example is the first value
// of that type found in them (walking AnglerData's fields in order).

const dataType = objectByName.get('Data');
for (const f of dataType.fields) if (!dataFields[f.json]) throw new Error(`docs-content: no entry for data field ${f.json}`);
for (const k of Object.keys(dataFields)) if (!dataType.fields.some((f) => f.json === k)) throw new Error(`docs-content: AnglerData has no field ${k}`);
for (const [k, d] of Object.entries(dataFields)) {
  validate(dataType.fields.find((f) => f.json === k).type, d.example, `${k}.example`);
  for (const e of d.events) if (!isStandard(e)) throw new Error(`docs-content: ${k}: ${e} isn't a standard event`);
}
if (eventOrder.length !== eventNames.length || !eventNames.every((e) => eventOrder.includes(e))) {
  throw new Error(`docs-content: eventOrder must list exactly the schema's events: ${eventNames.join(', ')}`);
}
for (const [u, values] of Object.entries(unionExamples)) values.forEach((v, i) => validate({ kind: 'union', name: u }, v, `${u}[${i}]`));

/** type name → example value; union name → [example per member] */
const examples = new Map();
/** type name → [{ parent, field }] */
const usedIn = new Map();
function collect(t, value) {
  if (t.kind === 'array') return value.forEach((v) => collect(t.of, v));
  if (t.kind === 'union') {
    const m = memberFor(unionByName.get(t.name), value);
    return collect({ kind: 'object', name: m }, value);
  }
  if (t.kind !== 'object') return;
  if (!examples.has(t.name)) examples.set(t.name, value);
  for (const f of objectByName.get(t.name).fields) if (f.json in value) collect(f.type, value[f.json]);
}
for (const f of dataType.fields) collect(f.type, dataFields[f.json].example);
for (const [u, values] of Object.entries(unionExamples)) values.forEach((v) => collect({ kind: 'union', name: u }, v));
for (const o of objects) {
  if (o.name !== 'Data' && !examples.has(o.name)) throw new Error(`docs-content: no example reaches ${T(o.name)}; add one`);
  for (const f of o.fields) {
    const inner = f.type.kind === 'array' ? f.type.of : f.type;
    if (inner.kind === 'object' || inner.kind === 'union') {
      usedIn.set(inner.name, [...(usedIn.get(inner.name) ?? []), { parent: o.name, field: f.json }]);
    }
  }
}
for (const u of unions) if (!unionExamples[u.name]) throw new Error(`docs-content: add unionExamples.${u.name}`);

// ---------------------------------------------------------------------------------------------
// Rendering a value as code. Lines wrap at WIDTH; nested values indent one level.

const WIDTH = 100;
const LANGS = {
  swift: { indent: '    ', trailing: '', str: (s) => JSON.stringify(s) },
  kotlin: { indent: '    ', trailing: ',', str: (s) => JSON.stringify(s).replace(/\$/g, '\\$') },
  ts: { indent: '  ', trailing: ',', str: (s) => `'${s.replace(/\\/g, '\\\\').replace(/'/g, "\\'")}'` },
  dart: { indent: '  ', trailing: ',', str: (s) => `'${s.replace(/\\/g, '\\\\').replace(/'/g, "\\'").replace(/\$/g, '\\$')}'` },
};

/** open + items + close, on one line if it fits after `lead` characters, else one item per line. */
function list(lang, open, items, close, ind, lead) {
  const one = open + items.join(', ') + close;
  if (!items.some((i) => i.includes('\n')) && ind.length + lead + one.length <= WIDTH) return one;
  return open + '\n' + items.map((i) => ind + LANGS[lang].indent + i).join(',\n') + LANGS[lang].trailing + '\n' + ind + close;
}

/** Code for `value` of type t. ind: the current line's indent; lead: characters before it on the line. */
function render(lang, t, value, ind, lead = 0) {
  const inner = ind + LANGS[lang].indent;
  switch (t.kind) {
    case 'string':
      return LANGS[lang].str(value);
    case 'number':
    case 'bool':
      return String(value);
    case 'array': {
      const items = value.map((v) => render(lang, t.of, v, inner));
      return lang === 'kotlin' ? list(lang, 'listOf(', items, ')', ind, lead) : list(lang, '[', items, ']', ind, lead);
    }
    case 'union': {
      const m = memberFor(unionByName.get(t.name), value);
      if (lang !== 'swift') return render(lang, { kind: 'object', name: m }, value, ind, lead);
      const open = `.${lowerFirst(m)}(`;
      return open + render(lang, { kind: 'object', name: m }, value, ind, lead + open.length) + ')';
    }
    case 'object': {
      const o = objectByName.get(t.name);
      const fields = o.fields.filter((f) => f.json in value); // schema order: Swift requires it
      const sep = { swift: ': ', dart: ': ', ts: ': ', kotlin: ' = ' }[lang];
      const items = fields.map((f) => `${f.json}${sep}${render(lang, f.type, value[f.json], inner, f.json.length + sep.length)}`);
      if (lang === 'ts') return items.length ? list(lang, '{ ', items, ' }', ind, lead).replace(/^\{ \n/, '{\n').replace(/\n(\s*) \}$/, '\n$1}') : '{}';
      return list(lang, `${T(o.name)}(`, items, ')', ind, lead);
    }
  }
}

const LANG_TITLES = { swift: 'Swift', kotlin: 'Kotlin', ts: 'React Native (TypeScript)', dart: 'Flutter (Dart)' };
const FENCE = { swift: 'swift', kotlin: 'kotlin', ts: 'ts', dart: 'dart' };

/** An `Angler.track(...)` call sending `data` (an AnglerData value) with `event`. */
export function trackCall(lang, event, data, eventId) {
  const ev = {
    swift: isStandard(event) ? `.${camel(event)}` : `.custom(${LANGS.swift.str(event)})`,
    kotlin: isStandard(event) ? `AnglerEvent.${cap(camel(event))}` : `AnglerEvent.Custom(${LANGS.kotlin.str(event)})`,
    ts: isStandard(event) ? `AnglerEvent.${camel(event)}` : LANGS.ts.str(event),
    dart: isStandard(event) ? `AnglerEvent.${camel(event)}` : `const AnglerEvent.custom(${LANGS.dart.str(event)})`,
  }[lang];
  const dataT = { kind: 'object', name: 'Data' };
  const inner = LANGS[lang].indent;
  const id = eventId && LANGS[lang].str(eventId);
  switch (lang) {
    case 'swift':
      return list(lang, 'Angler.track(', [ev, `data: ${render(lang, dataT, data, inner, 6)}`, ...(id ? [`eventId: ${id}`] : [])], ')', '', 0);
    case 'kotlin':
      return list(lang, 'Angler.track(', [ev, render(lang, dataT, data, inner), ...(id ? [`eventId = ${id}`] : [])], ')', '', 0);
    case 'ts': {
      const opts = { data: render(lang, dataT, data, inner + '  ', 6) };
      const body = [`data: ${opts.data}`, ...(id ? [`eventId: ${id}`] : [])];
      const optsCode = list(lang, '{ ', body, ' }', inner, 0).replace(/^\{ \n/, '{\n').replace(/\n(\s*) \}$/, '\n$1}');
      return list(lang, 'Angler.track(', [ev, optsCode], ')', '', 0) + ';';
    }
    case 'dart':
      return (
        'await ' +
        list(lang, 'Angler.track(', [ev, `data: const ${render(lang, dataT, data, inner, 12)}`, ...(id ? [`eventId: ${id}`] : [])], ')', '', 6) +
        ';'
      );
  }
}

/** A variable holding `value` of type `name`. */
export function valueDecl(lang, name, value) {
  const isUnion = unionByName.has(name);
  const t = isUnion ? { kind: 'union', name } : { kind: 'object', name };
  const v = lowerFirst(name);
  // Objects need no annotation; a union value does, to say which union it is.
  const lead = {
    swift: isUnion ? `let ${v}: ${T(name)} = ` : `let ${v} = `,
    kotlin: isUnion ? `val ${v}: ${T(name)} = ` : `val ${v} = `,
    ts: `const ${v}: ${T(name)} = `,
    dart: isUnion ? `const ${T(name)} ${v} = ` : `const ${v} = `,
  }[lang];
  return lead + render(lang, t, value, '', lead.length) + (lang === 'ts' || lang === 'dart' ? ';' : '');
}

// ---------------------------------------------------------------------------------------------
// Pages

const clean = (s) => (s ?? '').replace(/\s+/g, ' ').trim();
const link = (name, from) => `[${T(name)}](${from === 'index' ? '' : '../'}${pageOf(name)})`;

function typeLabel(t, from) {
  switch (t.kind) {
    case 'string': return 'string';
    case 'number': return 'number';
    case 'bool': return 'boolean';
    case 'array': return `list of ${typeLabel(t.of, from)}`;
    default: return link(t.name, from);
  }
}

function fieldText(o, f) {
  const note = fieldNotes[`${o.name}.${f.json}`];
  let text = clean(f.description);
  if (note) text = note.append ? [text, note.text].filter(Boolean).join(' ') : text || note.text;
  return (f.required ? '**Required.** ' : '') + text;
}

/** track's `properties` shortcut, which adds name/value pairs to customData. */
function propertiesSection() {
  const { event, properties } = propertiesExample;
  const pairs = Object.entries(properties);
  const code = {
    swift: `Angler.track(.custom(${LANGS.swift.str(event)}), properties: [${pairs.map(([k, v]) => `${LANGS.swift.str(k)}: ${LANGS.swift.str(v)}`).join(', ')}])`,
    kotlin: `Angler.track(\n    AnglerEvent.Custom(${LANGS.kotlin.str(event)}),\n    properties = mapOf(${pairs.map(([k, v]) => `${LANGS.kotlin.str(k)} to ${LANGS.kotlin.str(v)}`).join(', ')}),\n)`,
    ts: `Angler.track(${LANGS.ts.str(event)}, { properties: { ${pairs.map(([k, v]) => `${k}: ${LANGS.ts.str(v)}`).join(', ')} } });`,
    dart: `await Angler.track(\n  const AnglerEvent.custom(${LANGS.dart.str(event)}),\n  properties: {${pairs.map(([k, v]) => `${LANGS.dart.str(k)}: ${LANGS.dart.str(v)}`).join(', ')}},\n);`,
  };
  let out = '\n## Shortcut: `properties`\n\n`track`\'s `properties` argument takes plain string pairs and ' +
    'adds each one to `customData`, so this sends the same name/value pairs as the example above:\n\n';
  for (const lang of Object.keys(LANG_TITLES)) out += `**${LANG_TITLES[lang]}**\n\n\`\`\`${FENCE[lang]}\n${code[lang]}\n\`\`\`\n\n`;
  return out.trimEnd() + '\n';
}

function usedInSection(uses, from) {
  const byParent = new Map();
  for (const u of uses) byParent.set(u.parent, [...(byParent.get(u.parent) ?? []), u.field]);
  let out = '\n## Used in\n\n';
  for (const [parent, fields] of byParent) out += `- ${link(parent, from)}: ${fields.map((f) => `\`${f}\``).join(', ')}\n`;
  return out;
}

function examplesSection(snippets, json) {
  let out = '## Example\n\n';
  for (const lang of Object.keys(LANG_TITLES)) {
    out += `**${LANG_TITLES[lang]}**\n\n\`\`\`${FENCE[lang]}\n${snippets[lang]}\n\`\`\`\n\n`;
  }
  out += `**JSON sent**\n\n\`\`\`json\n${json}\n\`\`\`\n`;
  return out;
}

function eventsFor(field) {
  const d = dataFields[field];
  return d.events.length ? d.events.map((e) => `\`${e}\``).join(', ') : null;
}

function objectPage(o) {
  const dataField = dataType.fields.find((f) => {
    const inner = f.type.kind === 'array' ? f.type.of : f.type;
    return inner.name === o.name;
  });
  let out = `# ${T(o.name)}\n\n`;
  const meta = [];
  if (o.name === 'Data') meta.push('The `data` of every event: `track`\'s `data` argument.');
  if (dataField) {
    meta.push(`Sent as \`data.${dataField.json}\`${dataField.type.kind === 'array' ? ' (a list)' : ''}.`);
    const ev = eventsFor(dataField.json);
    if (ev) meta.push(`Usually sent with ${ev}.`);
  }
  const intro = typeNotes[o.name] ?? clean(o.description);
  if (intro) out += intro + '\n\n';
  if (meta.length) out += meta.join(' ') + '\n\n';
  out += '[All data objects](../README.md)\n\n## Fields\n\n';
  out += 'Every field is optional unless it says **Required**. Leave out what you don\'t have.\n\n';
  out += '| Field | Type | Description |\n|---|---|---|\n';
  for (const f of o.fields) out += `| \`${f.json}\` | ${typeLabel(f.type, o.name)} | ${fieldText(o, f).replace(/\|/g, '\\|')} |\n`;
  out += '\n';

  let snippets, json;
  if (o.name === 'Data') {
    const data = { cartLine: dataFields.cartLine.example, customData: [dataFields.customData.example[1]] };
    snippets = Object.fromEntries(Object.keys(LANG_TITLES).map((l) => [l, trackCall(l, 'product_added_to_cart', data)]));
    json = JSON.stringify(data, null, 2);
  } else if (dataField) {
    const d = dataFields[dataField.json];
    const data = { [dataField.json]: d.example };
    const event = d.exampleEvent ?? d.events[0];
    snippets = Object.fromEntries(Object.keys(LANG_TITLES).map((l) => [l, trackCall(l, event, data, d.eventId)]));
    json = JSON.stringify(data, null, 2);
    if (dataField.json === 'customData') {
      out += 'A custom event (any name that isn\'t a standard event) is sent as `custom_event`, with ' +
        'its name in `custom_event_name`. Its details go in `customData`.\n\n';
    }
  } else {
    const value = examples.get(o.name);
    snippets = Object.fromEntries(Object.keys(LANG_TITLES).map((l) => [l, valueDecl(l, o.name, value)]));
    json = JSON.stringify(value, null, 2);
  }
  out += examplesSection(snippets, json);
  if (dataField?.json === 'customData') out += propertiesSection();

  const uses = usedIn.get(o.name) ?? [];
  if (uses.length) {
    out += usedInSection(uses, o.name);
  }
  return out;
}

function unionPage(u) {
  let out = `# ${T(u.name)}\n\n${typeNotes[u.name] ?? `One of: ${u.members.map((m) => T(m)).join(', ')}.`}\n\n`;
  out += '[All data objects](../README.md)\n\n## One of\n\n';
  for (const m of u.members) out += `- ${link(m, u.name)}\n`;
  out += '\nIn Swift it\'s an enum with a case per type; in Kotlin and Dart both types implement it; ' +
    'in TypeScript it\'s a union of the two.\n\n## Examples\n';
  for (const value of unionExamples[u.name]) {
    const m = memberFor(u, value);
    out += `\n### ${T(m)}\n\n`;
    for (const lang of Object.keys(LANG_TITLES)) {
      out += `**${LANG_TITLES[lang]}**\n\n\`\`\`${FENCE[lang]}\n${valueDecl(lang, u.name, value)}\n\`\`\`\n\n`;
    }
    out += `**JSON sent**\n\n\`\`\`json\n${JSON.stringify(value, null, 2)}\n\`\`\`\n`;
  }
  const uses = usedIn.get(u.name) ?? [];
  if (uses.length) {
    out += usedInSection(uses, u.name);
  }
  return out;
}

function indexPage() {
  let out = '# Events and data objects\n\n';
  out += 'Every event can carry a `data` object, [AnglerData](data/README.md), with the commerce ' +
    'objects the event is about. Each SDK has typed classes for all of them (`AnglerData`, ' +
    '`AnglerCartLine`, `AnglerMoney`, …), generated from the events API\'s schema, so the field ' +
    'names below are the same in Swift, Kotlin, TypeScript, Dart and the JSON that\'s sent.\n\n';
  out += 'Each page lists the fields and shows a full example in every language. To install and ' +
    'configure the SDK, see the [main README](../README.md).\n\n';
  out += '## Events\n\n| Event | Data to attach |\n|---|---|\n';
  const byEvent = new Map();
  for (const [field, d] of Object.entries(dataFields)) for (const e of d.events) byEvent.set(e, [...(byEvent.get(e) ?? []), field]);
  for (const e of eventOrder) {
    const fields = byEvent.get(e) ?? [];
    const cell = fields.length
      ? fields.map((f) => {
          const t = dataType.fields.find((x) => x.json === f).type;
          return `\`${f}\` (${link(t.kind === 'array' ? t.of.name : t.name, 'index')})`;
        }).join(', ')
      : '—';
    out += `| \`${e}\` | ${cell} |\n`;
  }
  out += `| any other name (a custom event) | \`customData\` (${link('CustomValue', 'index')}) |\n\n`;
  out += '`app_installed` and `app_launched` are sent automatically.\n\n';
  out += '## Data objects\n\nThe fields of [AnglerData](data/README.md):\n\n| Field | Type | |\n|---|---|---|\n';
  for (const f of dataType.fields) {
    const inner = f.type.kind === 'array' ? f.type.of : f.type;
    out += `| \`${f.json}\` | ${f.type.kind === 'array' ? 'list of ' : ''}${link(inner.name, 'index')} | ${clean(fieldNotes[`Data.${f.json}`]?.text)} |\n`;
  }
  const top = new Set(dataType.fields.map((f) => (f.type.kind === 'array' ? f.type.of : f.type).name));
  out += '\n## Nested types\n\n';
  const nested = [
    ...objects.filter((o) => o.name !== 'Data' && !top.has(o.name)).map((o) => [o.name, typeNotes[o.name] ?? o.description]),
    ...unions.map((u) => [u.name, typeNotes[u.name]]),
  ].sort(([a], [b]) => a.localeCompare(b));
  for (const [name, text] of nested) out += `- ${link(name, 'index')}: ${clean(text)}\n`;
  out += '\n## Good to know\n\n';
  out += '- **Leave out what you don\'t have.** Every field is optional unless its page says ' +
    '**Required**, and fields you leave out aren\'t sent.\n';
  out += '- **Money** is a decimal amount in the currency\'s main unit (`29.99`, not `2999`) with an ' +
    'ISO 4217 currency code.\n';
  out += '- **IDs** are strings. Use the same product and variant IDs as your product catalog, so ad ' +
    'platforms can match them.\n';
  out += '- **Purchases:** on `checkout_completed`, set `checkout.order.id` and `checkout.totalPrice`, ' +
    'and pass the order ID as `eventId`, so the purchase isn\'t counted twice.\n';
  out += '- **Customer details** (email, phone, name) help match app activity to ad clicks. They\'re ' +
    'sent over HTTPS; the `hashed*` fields take SHA-256 hashes of lowercased values if you only ' +
    'have those.\n';
  out += '- **Untyped form:** every SDK also takes `data` as a plain map or JSON object with these ' +
    'same keys (`trackJson` in Flutter).\n';
  out += '\n<sub>Generated by `scripts/generate-docs.mjs` from the schema snapshot in `spec/schema` and ' +
    '`scripts/docs-content.mjs`. Edit those, not these pages.</sub>\n';
  return out;
}

// ---------------------------------------------------------------------------------------------

export function pages() {
  const footer = '\n<sub>Generated by `scripts/generate-docs.mjs`; edit `scripts/docs-content.mjs` or the schema, not this page.</sub>\n';
  const out = { 'README.md': indexPage() };
  for (const o of objects) out[pageOf(o.name)] = objectPage(o) + footer;
  for (const u of unions) out[pageOf(u.name)] = unionPage(u) + footer;
  return out;
}

export { examples, dataFields, LANG_TITLES, render, unionExamples };

if (import.meta.url === pathToFileURL(process.argv[1]).href) {
  const check = process.argv.includes('--check');
  const docs = join(root, 'docs');
  const want = pages();
  const wantDirs = new Set(Object.keys(want).filter((p) => p.includes('/')).map((p) => p.split('/')[0]));
  let stale = 0;
  for (const [path, content] of Object.entries(want)) {
    const file = join(docs, path);
    const current = existsSync(file) ? readFileSync(file, 'utf8') : null;
    if (current === content) continue;
    if (check) {
      console.error(`generate-docs: docs/${path} is out of date`);
      stale++;
    } else {
      mkdirSync(join(file, '..'), { recursive: true });
      writeFileSync(file, content);
    }
  }
  // Pages for types that no longer exist. Other folders (and docs/superpowers, which is ignored) stay.
  for (const dir of existsSync(docs) ? readdirSync(docs, { withFileTypes: true }) : []) {
    if (!dir.isDirectory() || wantDirs.has(dir.name)) continue;
    const readme = join(docs, dir.name, 'README.md');
    if (!existsSync(readme) || !readFileSync(readme, 'utf8').includes('Generated by `scripts/generate-docs.mjs`')) continue;
    if (check) {
      console.error(`generate-docs: docs/${dir.name} is for a type that no longer exists`);
      stale++;
    } else rmSync(join(docs, dir.name), { recursive: true });
  }
  if (check && stale) {
    console.error('Run `node scripts/generate-docs.mjs` and commit the result.');
    process.exit(1);
  }
  console.log(`generate-docs: ${Object.keys(want).length} pages ${check ? 'up to date' : 'written'}`);
}
