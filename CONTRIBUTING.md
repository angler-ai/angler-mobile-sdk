# Contributing

## How the repo fits together

- **`spec/` comes first.** It holds a snapshot of the events API's request schema
  (`spec/schema`) and shared fixtures (`spec/fixtures`): deep-link parsing, payloads, response
  handling, backoff and typed data. Every SDK's tests run against the same fixtures, so a
  behaviour change starts with a fixture change.
- **Native cores, thin wrappers.** The queue, device info, ad IDs and attribution live in Swift
  (`ios/`) and Kotlin (`android/`). React Native and Flutter only translate calls.
- **The typed models are generated.** `AnglerEvent`, `AnglerData` and the nested `Angler*`
  types in all four languages come from the schema snapshot. Don't edit the `*.generated.*`
  files by hand.
- **So are the docs.** `docs/` is generated from the same snapshot plus the examples and notes
  in `scripts/docs-content.mjs` (`node scripts/generate-docs.mjs`). Edit that file, not the
  pages. The generator checks every example against the schema.
- **One version.** `VERSION` at the root is the only place to change it.

## Tools

| For | You need |
|---|---|
| iOS | Xcode 16+ |
| Android | JDK 17+ and the Android SDK (Android Studio's bundled JDK works) |
| React Native | Node 20+ |
| Flutter | Flutter 3.24+ |
| spec and scripts | Node 20+ |

## Running the tests

CI runs these on every pull request (only for the platforms a change touches):

```sh
# spec fixtures and scripts
(cd spec && npm ci && npm test)
node --test scripts/test/
node scripts/sync-version.mjs --check
node scripts/generate-models.mjs --check
node scripts/generate-docs.mjs --check

# iOS
swift test
xcodebuild test -scheme AnglerAnalytics -destination 'platform=iOS Simulator,name=iPhone 16'

# Android
(cd android && ./gradlew :angler-analytics:testDebugUnitTest :angler-analytics:lint)

# React Native
(cd react-native && npm ci && npx jest && npx tsc --noEmit && node --test scripts/__tests__/)

# Flutter
(cd flutter && flutter test && flutter analyze)
(cd flutter && scripts/sync_native.sh && scripts/check_package.sh)
```

The wrappers' Android code builds against the Kotlin core from `mavenLocal` in CI:
`(cd android && ./gradlew publishToMavenLocal)` first, then build the example apps.

## Common changes

**The events API added a field or event.** Re-export the schema snapshot from the API repo,
regenerate the models and docs, and commit them all:

```sh
node spec/scripts/export-schema.mjs <path to the API repo> origin/main
node scripts/generate-models.mjs
node scripts/generate-docs.mjs
```

A new object type needs an example: the docs generator fails until `scripts/docs-content.mjs`
has one that reaches it.

**Swift core changed.** The React Native and Flutter packages compile a copy of the Swift
sources. CI and the publish scripts copy it for you; to build the example apps locally, run
`node react-native/scripts/sync-native.mjs` or `flutter/scripts/sync_native.sh` first. The
copies are gitignored.

**Version.** Edit `VERSION`, then run `node scripts/sync-version.mjs`. It updates the Swift,
Kotlin, npm and pub version fields and the install snippets in the READMEs. See
[RELEASING.md](RELEASING.md).

## Example apps

`examples/` has a small app per platform that builds the SDK from this repo. Each has a README
with run instructions. They point at the dev environment; never commit a real workspace token.

## Pull requests

- Keep the repo small: SPM clones all of it for every iOS app, so no binaries or build output.
- Add or update a fixture in `spec/fixtures` for any change to what gets sent.
- This repo is public. Don't commit tokens, customer data or internal links.
