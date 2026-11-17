#!/usr/bin/env bash
# Fails unless the pub.dev archive (per `dart pub publish --dry-run`) contains the copied
# Swift core. Pub prints a tree, so full paths are rebuilt from the indentation.
# Usage: scripts/check_package.sh [required-path ...]
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
required=("$@")
[ ${#required[@]} -eq 0 ] && required=(
  ios/Classes/vendor/AnglerAnalytics/AnglerCore.swift
  ios/Classes/vendor/AnglerAnalytics/Resources/PrivacyInfo.xcprivacy
  ios/Classes/AnglerAnalyticsPlugin.swift
)
out="$(dart pub publish --dry-run 2>&1)"
status=$?
paths="$(printf '%s\n' "$out" | python3 -c '
import re, sys
stack = []
for line in sys.stdin:
    m = re.match(r"^((?:│   |    )*)[├└]── (.+?)(?: \([^)]*\))?\s*$", line.rstrip("\n"))
    if not m:
        continue
    depth = len(m.group(1)) // 4
    stack = stack[:depth] + [m.group(2)]
    print("/".join(stack))
')"
missing=0
for p in "${required[@]}"; do
  if ! grep -qxF "$p" <<<"$paths"; then
    echo "missing from package: $p"
    missing=1
  fi
done
if [ $status -ne 0 ]; then
  printf '%s\n' "$out" | sed -n '/Package validation found the following error/,/^$/p'
  echo "dart pub publish --dry-run failed (exit $status)"
  exit 1
fi
[ $missing -eq 0 ] && echo "package ok: ${#required[@]} required files present"
exit $missing
