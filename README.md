# Angler Mobile SDK

Send app events and ad-attribution signals from iOS, Android, React Native and Flutter apps
to [Angler](https://getangler.ai). The SDKs capture what the web pixel captures on a website,
plus the app-only signals ad platforms need: install and launch events, device details,
advertising IDs (IDFA/GAID), click IDs from deep links and the Play Install Referrer.

| Platform | Package | Install | Guide |
|---|---|---|---|
| iOS (Swift) | `AnglerAnalytics` (Swift Package Manager) | `.package(url: "https://github.com/angler-ai/angler-mobile-sdk", exact: "0.1.0-rc.2")` | [ios/](ios/README.md) |
| Android (Kotlin, Java) | `ai.getangler:analytics` (Maven Central) | `implementation("ai.getangler:analytics:0.1.0-rc.2")` | [android/](android/README.md) |
| React Native | [`@anglerai/react-native-analytics`](https://www.npmjs.com/package/@anglerai/react-native-analytics) (npm) | `npm install @anglerai/react-native-analytics` | [react-native/](react-native/README.md) |
| Flutter | [`angler_analytics`](https://pub.dev/packages/angler_analytics) (pub.dev) | `angler_analytics: ^0.1.0-rc.2` | [flutter/](flutter/README.md) |

All four share one version and behave the same way: the React Native and Flutter packages are
thin wrappers over the Swift and Kotlin cores.

## Quick start

You need a **workspace ID** and a **workspace token** from Angler. Configure once at startup,
then track events:

```swift
// iOS
Angler.configure(AnglerConfiguration(workspaceId: "<workspace id>", token: "<workspace token>"))
Angler.track(.productViewed, data: AnglerData(productVariant: AnglerProductVariant(id: "variant-1")))
```

```kotlin
// Android
Angler.configure(this, AnglerConfiguration(workspaceId = "<workspace id>", token = "<workspace token>"))
Angler.track(AnglerEvent.ProductViewed, AnglerData(productVariant = AnglerProductVariant(id = "variant-1")))
```

```ts
// React Native
Angler.configure({ workspaceId: '<workspace id>', token: '<workspace token>' });
Angler.track(AnglerEvent.productViewed, { data: { productVariant: { id: 'variant-1' } } });
```

```dart
// Flutter
await Angler.configure(const AnglerConfiguration(workspaceId: '<workspace id>', token: '<workspace token>'));
await Angler.track(AnglerEvent.productViewed, data: const AnglerData(productVariant: AnglerProductVariant(id: 'variant-1')));
```

Then, in every app:

1. **Forward deep links** (custom schemes and universal/app links) to `Angler.handleDeepLink`,
   so click IDs from ads are captured. React Native does this for you.
2. **Track the shopping funnel** with the [standard events](#events) below.
3. **Call `setUserId`** when the shopper logs in, and `reset` when they log out.
4. **If checkout happens on the web** (for example Shopify's checkout in a web view), pass
   `getClientId()` to it as the cart attribute `_angler_client_id`, so the order is linked to
   the app. See your SDK's guide.
5. **Ask for tracking permission on iOS** (ATT) if you want the IDFA sent. The SDK never shows
   the prompt itself.
6. **Test against the dev environment** with `domain: "dev-data.getangler.ai"` and
   `debugLogging: true` before you ship. See [Verifying your integration](#verifying-your-integration).

## Events

Pass one of these names (each SDK has them as `AnglerEvent`), or any other string for a
custom event. Every event can carry the data objects below; the second column is what's usually
attached.

| Event | Typical data | Notes |
|---|---|---|
| `app_installed` | — | Sent automatically on the first run with the SDK. |
| `app_launched` | — | Sent automatically on a cold start and after 30+ minutes in the background. |
| `page_viewed` | — | A screen view. |
| `product_viewed` | `productVariant` | |
| `collection_viewed` | `collection` | |
| `search_submitted` | `searchResult` | |
| `product_added_to_cart` | `cartLine` | |
| `product_removed_from_cart` | `cartLine` | |
| `cart_viewed` | `cart` | |
| `checkout_started` | `checkout` | |
| `checkout_contact_info_submitted` | `checkout` | |
| `checkout_address_info_submitted` | `checkout` | |
| `checkout_shipping_info_submitted` | `checkout` | |
| `payment_info_submitted` | `checkout` | |
| `checkout_completed` | `checkout` | Pass your order ID as `eventId` so the purchase isn't counted twice. |
| `form_submitted` | `form` | |
| `registration_completed` | `customer` | |
| `logged_in` | `customer` | |
| anything else | `customData` | Sent as `custom_event` with your name in `custom_event_name`. |

**Data objects** are typed in every SDK (`AnglerData`, `AnglerProductVariant`, `AnglerMoney`,
…) and follow Shopify's web pixel shapes: `cart`, `cartLine`, `checkout`, `collection`,
`productVariant`, `searchResult`, `customer`, `form`, `contacts` and `customData`. Extra
string key/value pairs passed as `properties` are added to `customData`. The types are generated
from the API schema in [`spec/schema`](spec/schema), so the compiler catches fields the API
doesn't accept.

**[docs/](docs/README.md) has a page for every data object**, with all its fields and an example
in Swift, Kotlin, TypeScript, Dart and JSON.

## What the SDK collects

**Identifiers** (sent in `identifiers`):

| Name | Value | When |
|---|---|---|
| `aid` | Install ID: a random UUID created on first launch and kept on the device. A reinstall or `reset()` creates a new one. | Always. It's also the default `client_id`. |
| `customer_id` | The ID you pass to `setUserId`. | After `setUserId`. |
| `idfa` | iOS advertising ID. | Only when the user allowed tracking (ATT authorized). |
| `gaid` | Android advertising ID. | Unless the user opted out of ad personalization, Play services are missing, or the app removed the `AD_ID` permission. |
| `firebase_app_instance_id` | Firebase Analytics' app instance ID. | When the app uses Firebase Analytics. Nothing to install. |
| `gclid`, `gbraid`, `wbraid`, `gad_source`, `fbclid`, `ttclid`, `sccid`, `rdt_cid`, `epik` | Click IDs from ad links. | After a deep link (or Play Install Referrer) carrying them. Kept 400 days. |
| anything else | Your values from `setIdentifier(name, value)`. | After you set them. |

When a `fbclid` arrives, the SDK also sends Meta's `fbc` value. The deep link itself is sent as
`url` on every event until the app spends 30 minutes in the background.

**Device properties** (sent in `device_properties`): app package and version, App Store ID or
package name (`app_id`), OS and version, device model, time zone, locale, screen size and
density, CPU cores, `advertiser_tracking_enabled` and `application_tracking_enabled`. Android
also sends the mobile carrier and storage size. The SDK's name, version, OS and device model go
in `user_agent`, for example `AnglerAnalytics/0.1.0 (iOS 18.1; iPhone16,2; native)`.

## Delivery

Events are written to a queue on the device first, so nothing is lost when the app is offline
or killed. The queue is sent:

- when it holds `flushAt` events (20 by default),
- every `flushIntervalSeconds` (30 by default),
- when the app goes to the background,
- when you call `Angler.flush()`.

Requests go to `https://<domain>/v1/workspaces/<workspace id>/events` with the token as a
bearer token, at most 100 events per request.

| Response | What the SDK does |
|---|---|
| 2xx | Removes the events from the queue. |
| Network error, 429, 5xx | Retries with exponential backoff (up to 5 minutes between attempts). |
| 400 | Retries each event on its own and drops only the ones the API rejects. |
| 413 | Splits the batch and retries. |
| 401, 403 | Stops sending until the next app launch and logs an error: check the token. Events stay queued. |

The queue keeps at most `maxQueueSize` events (1000 by default). Past that, the oldest are
dropped.

## Privacy and consent

- **No prompts.** The SDK never shows the iOS App Tracking Transparency prompt. Your app owns
  it, and the SDK reads the status on every event.
- **Opt-out:** `setEnabled(false)` stops collection and deletes queued events. It's remembered
  across launches.
- **In-app tracking choice:** `setApplicationTrackingEnabled(false)` is sent as
  `application_tracking_enabled`, so ad platforms treat the user as opted out.
- **Logout:** `reset()` clears the user ID, custom identifiers, stored click IDs and the session
  URL, and starts a new install ID.
- **URLs:** the full deep-link URL is sent. Don't forward URLs that carry secrets (OAuth codes,
  magic-link or password-reset tokens, email addresses): remove those parameters first.
- **iOS privacy manifest:** the package ships a `PrivacyInfo.xcprivacy` listing the data it
  collects. Include the same data types in your App Store privacy details.
- **Android:** the library adds the `AD_ID` permission. Apps that must not use the advertising
  ID (for example, apps for children) remove it; see the [Android guide](android/README.md).

## Configuration

| Option | Default | What it does |
|---|---|---|
| `workspaceId`, `token` | required | Your Angler workspace and its token. |
| `domain` | `data.getangler.ai` | Use `dev-data.getangler.ai` while testing. |
| `clientId` | install ID | Overrides `client_id`, for example to match an ID from another system. |
| `appStoreId` (iOS, React Native, Flutter) | none | Your App Store ID (`id1234567890`), sent as `app_id`. TikTok's app events need it. Android always sends the package name (override with `appId` on native Android). |
| `trackLifecycleEvents` | `true` | Send `app_installed` and `app_launched`. |
| `flushAt` | `20` | Queued events that trigger a send. |
| `flushIntervalSeconds` (`flushInterval` on iOS) | `30` | Seconds between periodic sends. |
| `maxQueueSize` | `1000` | Oldest events are dropped beyond this. |
| `debugLogging` | `false` | Log every queued and delivered event. |
| `autoHandleDeepLinks` (React Native) | `true` | Forward every `Linking` URL automatically. |

No method throws, and everything except `track` can be called before `configure`. A `track`
before `configure` is dropped with a warning. A second `configure` in the same process is
ignored.

## Verifying your integration

1. Configure with `domain: "dev-data.getangler.ai"` and `debugLogging: true`.
2. Launch the app. You should see `queued app_installed` (on the first run), `queued app_launched`
   and then `delivered 2 event(s)` in the logs:
   - **iOS:** Xcode console, or Console.app filtered on subsystem `ai.getangler.analytics`.
   - **Android:** `adb logcat -s Angler`.
   - **React Native / Flutter:** the native logs above (Xcode or logcat).
3. Open a deep link with a click ID (`yourapp://product/1?gclid=test`), track an event, and
   check with Angler that it arrived with `gclid`.
4. An `HTTP 401` or `403` error in the logs means the workspace ID or token is wrong.

Switch `domain` back to the default and `debugLogging` off before you release.

## Repository

```
Package.swift   SPM manifest (must be at the repo root); points into ios/
spec/           API schema snapshot and shared test fixtures every SDK runs against
docs/           a reference page per event data object (generated)
ios/            Swift core
android/        Kotlin core
react-native/   React Native wrapper (TurboModule)
flutter/        Flutter plugin
examples/       a small sample app per platform
scripts/        version sync, typed-model and docs generation
```

- [CONTRIBUTING.md](CONTRIBUTING.md): building, testing and changing the SDKs.
- [RELEASING.md](RELEASING.md): publishing a new version to all four registries.

## License

[MIT](LICENSE)
