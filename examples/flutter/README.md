# Flutter example

A Flutter app that uses `angler_analytics` from this repo (`path: ../../flutter`) and forwards
deep links with `app_links`. It configures against `dev-data.getangler.ai`; put a dev workspace
ID and token in `lib/main.dart` before sending real events (never commit a real token).

## iOS

```sh
../../flutter/scripts/sync_native.sh   # copy the Swift core into the plugin
flutter run                            # or: flutter build ios --simulator --debug
xcrun simctl openurl booted "anglerexample://p/1?gclid=fl-cold"
```

## Android

The plugin depends on the Maven artifact `ai.getangler:analytics` at the plugin's version. The
example also looks in `mavenLocal`, so to build before a version is on Maven Central, publish
the core there first: `cd ../../android && ./gradlew publishToMavenLocal`.

```sh
flutter run
```

```sh
adb shell am start -a android.intent.action.VIEW -d "anglerexample://p/1?gclid=fl-cold"
```

## Known issues

- **iOS 27 simulators:** this Flutter template has no UIScene lifecycle, which iOS 27 enforces at
  launch, so the app crashes there. Use an iOS 26 (or earlier) simulator.
- **Xcode 27 beta:** `flutter build ios` can fail parsing `lipo` output. Build with
  `xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -destination 'id=<sim>' ARCHS=arm64 build` instead.
- The Podfile raises every pod to iOS 15.0, which newer Xcode requires.
