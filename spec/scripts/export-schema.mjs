// Usage: node scripts/export-schema.mjs <path-to-data-api> [git-ref]
//
// Writes data-api's WorkspacesEventsPostBody (api/src/schema/events.ts) to
// schema/events-post-body.schema.json. Never hand-edit the output; re-export.
// With no git-ref, the data-api working tree is exported. With a git-ref
// (for example origin/main), that commit's events.ts is exported instead, so a
// checkout on a feature branch doesn't leak into the snapshot.
import { execFileSync } from 'node:child_process';
import { mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const [dataApi, ref] = process.argv.slice(2);
if (!dataApi) {
  console.error('usage: node scripts/export-schema.mjs <path-to-data-api> [git-ref]');
  process.exit(2);
}
const repo = resolve(dataApi);
const schemaPath = 'api/src/schema/events.ts';
const specDir = join(dirname(fileURLToPath(import.meta.url)), '..');
const git = (...args) => execFileSync('git', ['-C', repo, ...args], { encoding: 'utf8' }).trim();

const tmp = mkdtempSync(join(tmpdir(), 'angler-schema-'));
try {
  let source = join(repo, schemaPath);
  let sha = git('rev-parse', '--short', 'HEAD');
  if (ref) {
    sha = git('rev-parse', '--short', ref);
    source = join(tmp, 'events.ts');
    writeFileSync(source, git('show', `${ref}:${schemaPath}`));
  }
  const loader = join(tmp, 'load.ts');
  // Also exports the named data types (WorkspaceEventBodyMoney → Money, …) so the typed SDK
  // models (scripts/generate-models.mjs) can reuse data-api's names.
  writeFileSync(
    loader,
    `import * as m from ${JSON.stringify(source)};\n` +
      'const types = Object.fromEntries(Object.entries(m)\n' +
      '  .filter(([k]) => /^WorkspaceEvents?Body[A-Z]/.test(k))\n' +
      "  .map(([k, v]) => [k.replace(/^WorkspaceEvents?Body/, ''), v]));\n" +
      'process.stdout.write(JSON.stringify({ body: m.WorkspacesEventsPostBody, types }));\n'
  );
  const json = execFileSync('npx', ['--yes', 'tsx', loader], { encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 });
  const { body, types } = JSON.parse(json);
  const comment = `exported from data-api ${sha}`;
  const out = join(specDir, 'schema', 'events-post-body.schema.json');
  writeFileSync(out, JSON.stringify({ $comment: comment, ...body }, null, 2) + '\n');
  const typesOut = join(specDir, 'schema', 'event-data-types.json');
  writeFileSync(typesOut, JSON.stringify({ $comment: comment, ...types }, null, 2) + '\n');
  console.log(`wrote ${out} and ${typesOut} (data-api ${sha})`);
} finally {
  rmSync(tmp, { recursive: true, force: true });
}
