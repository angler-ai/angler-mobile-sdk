# Angler Mobile SDK

Angler analytics and ad attribution for native and cross-platform apps. These SDKs are the app equivalent of the web pixel in `events_lib`.

| Platform | Folder | Registry |
|---|---|---|
| iOS (Swift) | `ios/` | Swift Package Manager (`Package.swift` at the repo root) |
| Android (Kotlin, callable from Java) | `android/` | Maven Central |
| React Native | `react-native/` | npm |
| Flutter | `flutter/` | pub.dev |

## Layout

```
Package.swift      # SPM requires it at the repo root; points into ios/ (added with the Swift core)
spec/              # event schema + shared test fixtures, the source of truth for every SDK
ios/               # Swift core
android/           # Kotlin core
react-native/      # thin wrapper over the native cores
flutter/           # thin wrapper over the native cores
examples/          # minimal sample apps per platform
scripts/           # version sync and other repo tooling
docs/superpowers/  # design doc and implementation plans (internal; move out before the repo goes public)
.github/workflows/ # per-platform CI; one release tag publishes to all registries
```

Start with the [roadmap](docs/superpowers/plans/README.md) and the [design doc](docs/superpowers/specs/2026-11-17-mobile-sdk-design.md).

## Conventions

- **The spec comes first.** Payload shape, identifier names and deep-link click-ID parsing are defined in `spec/`. Every SDK's tests run against the shared fixtures there. Change the spec and the fixtures before any SDK code.
- **Native cores, thin wrappers.** Device info, ad IDs (IDFA/GAID), the persistent queue and attribution live in Swift and Kotlin. React Native and Flutter call into them. On iOS the wrappers compile a copy of the Swift sources (`react-native/scripts/sync-native.mjs` on `prepack`, `flutter/scripts/sync_native.sh` before publishing), so they don't depend on CocoaPods trunk, which is going read-only.
- **Lockstep versions.** All four SDKs share one version. Release tags are plain semver (`1.4.0`, not `ios-v1.4.0`) because SPM only resolves those.
- **Keep the repo small.** SPM clones the whole repo for iOS consumers, so keep example apps small and never commit build outputs or binaries.
