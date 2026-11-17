// Copies the Swift core (every .swift file under ios/Sources/AnglerAnalytics, plus the privacy
// manifest) into ios/vendor/AnglerAnalytics so the pod compiles it from source. Runs on prepack.
// Usage: node scripts/sync-native.mjs [sourceDir] [destDir]
import { copyFileSync, mkdirSync, readdirSync, rmSync, statSync } from 'node:fs';
import { dirname, join, relative } from 'node:path';
import { fileURLToPath } from 'node:url';

const pkgDir = join(dirname(fileURLToPath(import.meta.url)), '..');
const src = process.argv[2] ?? join(pkgDir, '..', 'ios', 'Sources', 'AnglerAnalytics');
const dest = process.argv[3] ?? join(pkgDir, 'ios', 'vendor', 'AnglerAnalytics');
const privacyManifest = join('Resources', 'PrivacyInfo.xcprivacy');

function walk(dir) {
  return readdirSync(dir).flatMap((name) => {
    const p = join(dir, name);
    return statSync(p).isDirectory() ? walk(p) : [p];
  });
}

const files = walk(src)
  .map((p) => relative(src, p))
  .filter((f) => f.endsWith('.swift') || f === privacyManifest);
if (!files.some((f) => f.endsWith('.swift'))) {
  console.error(`sync-native: no Swift sources found in ${src}`);
  process.exit(1);
}

// Start clean so files deleted from the core disappear from the package.
rmSync(dest, { recursive: true, force: true });
for (const f of files) {
  mkdirSync(dirname(join(dest, f)), { recursive: true });
  copyFileSync(join(src, f), join(dest, f));
}
console.log(`sync-native: copied ${files.length} files to ${relative(process.cwd(), dest) || dest}`);
