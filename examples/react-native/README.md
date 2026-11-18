# React Native example

A React Native 0.76 app (New Architecture) that uses `@anglerai/react-native-analytics` from
this repo (`file:../../react-native`). It configures against `dev-data.getangler.ai`; put a dev
workspace ID and token in `App.tsx` before sending real events (never commit a real token).

## iOS

```sh
npm install
npm run pods          # copies the Swift core into the package, then pod install
npm run ios           # or open ios/AnglerExample.xcworkspace
```

Cold-start deep link test (app killed first):

```sh
xcrun simctl openurl booted "anglerexample://p/1?gclid=rn-cold"
```

## Android

The Android module depends on the Maven artifact `ai.getangler:analytics` at the package's
version. The example also looks in `mavenLocal`, so to build before a version is on Maven
Central, publish the core there first: `cd ../../android && ./gradlew publishToMavenLocal`.

```sh
npm install
npm run android
```

```sh
adb shell am start -a android.intent.action.VIEW -d "anglerexample://p/1?gclid=rn-cold"
```

## Known issues

- **iOS 27 simulators:** the React Native 0.76 template has no UIScene lifecycle, which iOS 27
  enforces at launch, so the app crashes there. Use an iOS 26 (or earlier) simulator.
- **fmt with newer Xcode:** the Podfile builds the `fmt` pod as C++17 to avoid consteval errors.
