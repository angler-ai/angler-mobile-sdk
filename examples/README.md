# Examples

A small app per platform that builds the SDK from this repo and sends to the dev environment.

| App | Run it |
|---|---|
| [`ios/`](ios) | Open `AnglerExample.xcodeproj` (generated from `project.yml` with XcodeGen) and run. Credentials go in a gitignored `Local.xcconfig` (see `Config.xcconfig`). |
| [`android/`](android) | `./gradlew :app:installDebug -PanglerWorkspaceId=<id> -PanglerToken=<token>`. Builds the Kotlin core from `../../android`. |
| [`react-native/`](react-native/README.md) | See its README. |
| [`flutter/`](flutter/README.md) | See its README. |

Put a dev workspace ID and token in the app before sending real events, and never commit a real
token. Keep these apps small: SPM clones this whole repo for every iOS app that depends on it.
