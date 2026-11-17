#!/usr/bin/env bash
# Mirrors the Swift core (every .swift file, plus the privacy manifest) from
# ios/Sources/AnglerAnalytics into flutter/ios/Classes/vendor/AnglerAnalytics, deleting files
# that no longer exist in the core. Run before `dart pub publish` and before building the
# example app.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
src="$here/../ios/Sources/AnglerAnalytics/"
dest="$here/ios/Classes/vendor/AnglerAnalytics/"
mkdir -p "$dest"
rsync -a --delete --prune-empty-dirs \
  --include='*/' --include='*.swift' --include='Resources/PrivacyInfo.xcprivacy' --exclude='*' \
  "$src" "$dest"
echo "sync_native: $(find "$dest" -type f | wc -l | tr -d ' ') files in ios/Classes/vendor/AnglerAnalytics"
