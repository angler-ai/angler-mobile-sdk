# angler_analytics

Angler app events and ad-attribution signals for Flutter apps on iOS and Android. A thin
wrapper over the native Angler SDKs.

For the list of events, what the SDK collects and how delivery works, see the
[main README](https://github.com/angler-ai/angler-mobile-sdk#readme).

## Requirements

Flutter 3.24+, iOS 15+, Android minSdk 21. On other platforms (web, desktop) every call does
nothing.

## Install

```yaml
dependencies:
  angler_analytics: ^0.1.0-rc.2
```

iOS compiles the Swift core from source inside the plugin, and Android pulls
`ai.getangler:analytics` from Maven Central at the same version. Set the iOS deployment
target to 15.0 or later: `platform :ios, '15.0'` in `ios/Podfile`.

## Configure

Call `WidgetsFlutterBinding.ensureInitialized()` **before** `Angler.configure`. Without it the
platform channel isn't ready, the call is ignored, and nothing is tracked.

```dart
import 'package:angler_analytics/angler_analytics.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Angler.configure(const AnglerConfiguration(
    workspaceId: '<workspace id>',
    token: '<workspace token>',
    appStoreId: 'id1234567890', // optional; sent as app_id on iOS (TikTok app events need it)
  ));
  runApp(const MyApp());
}
```

A hot restart re-running `configure` is ignored.

| Option | Default | |
|---|---|---|
| `domain` | `'data.getangler.ai'` | `'dev-data.getangler.ai'` while testing. |
| `clientId` | install ID | Overrides `client_id`. |
| `appStoreId` | none | Your App Store ID, sent as `app_id` on iOS. Android sends the package name. |
| `trackLifecycleEvents` | `true` | Send `app_installed` and `app_launched`. |
| `flushAt` | `20` | Queued events that trigger a send. |
| `flushIntervalSeconds` | `30` | Seconds between periodic sends. |
| `maxQueueSize` | `1000` | Oldest events are dropped beyond this. |
| `debugLogging` | `false` | Log every queued and delivered event (in the native logs). |

## Track events

```dart
// Standard events, with typed data objects
await Angler.track(AnglerEvent.productViewed, data: const AnglerData(
  productVariant: AnglerProductVariant(
    id: 'variant-1', title: 'Linen shirt', price: AnglerMoney(amount: 29, currencyCode: 'USD')),
));

await Angler.track(AnglerEvent.productAddedToCart, data: const AnglerData(
  cartLine: AnglerCartLine(
    quantity: 1,
    merchandise: AnglerProductVariant(id: 'variant-1', price: AnglerMoney(amount: 29, currencyCode: 'USD')),
  ),
));

await Angler.track(
  AnglerEvent.checkoutCompleted,
  data: const AnglerData(checkout: AnglerCheckout(
    currencyCode: 'USD', totalPrice: AnglerMoney(amount: 58, currencyCode: 'USD'))),
  eventId: 'order-1001', // your order ID, so the purchase isn't counted twice
);

// Custom events; properties are added to data.customData
await Angler.track(const AnglerEvent.custom('wishlist_added'), properties: {'product_id': 'variant-1'});

// Untyped form: a string name and a JSON-like map with AnglerData's keys
await Angler.trackJson('product_viewed', data: {'productVariant': {'id': 'variant-1'}});
```

`AnglerEvent` has a constant per [standard event](https://github.com/angler-ai/angler-mobile-sdk#events).
`AnglerData` has one field per data object: `cart`, `cartLine`, `checkout`, `collection`,
`productVariant`, `searchResult`, `customer`, `form`, `contacts` and `customData`.

No method throws. Problems (no plugin on this platform, platform errors) are reported with
`debugPrint`. With `trackJson`, `data` that `jsonEncode` can't handle (for example a `DateTime`)
is dropped and the event is still sent.

## Deep links

Flutter has no built-in deep-link stream, so forward the URLs your app receives, so click IDs
from ads are captured. With [`app_links`](https://pub.dev/packages/app_links):

```dart
final appLinks = AppLinks();
final initial = await appLinks.getInitialLink();
if (initial != null) await Angler.handleDeepLink(initial.toString());
appLinks.uriLinkStream.listen((uri) => Angler.handleDeepLink(uri.toString()));
```

Register your URL scheme (and universal/app links) on both platforms. If you use `app_links`,
turn off Flutter's own deep-link handling so the links reach it: `FlutterDeepLinkingEnabled = NO`
in `ios/Runner/Info.plist`, and
`<meta-data android:name="flutter_deeplinking_enabled" android:value="false"/>` in the Android
activity.

## Identity, consent and opt-out

```dart
await Angler.setUserId('customer-42');                 // customer_id; null clears it
await Angler.setIdentifier('loyalty_id', 'L-123');     // custom identifier; null removes it
await Angler.setApplicationTrackingEnabled(false);     // the user declined tracking in your app
await Angler.setEnabled(false);                        // stop collecting and delete queued events
await Angler.reset();                                  // on logout
await Angler.flush();                                  // send the queue now
```

- **iOS tracking permission (ATT):** the SDK never shows the prompt. Request it yourself, for
  example with `app_tracking_transparency`, and add `NSUserTrackingUsageDescription` to
  `Info.plist`. The IDFA is sent only once tracking is authorized.
- **Android advertising ID:** the plugin adds the `AD_ID` permission. Apps that must not use it
  remove it with `tools:node="remove"` in `AndroidManifest.xml`.
- **Firebase:** if the app uses Firebase Analytics (`firebase_analytics`), its app instance ID is
  sent as `firebase_app_instance_id`. Nothing to configure.

## Web checkout

If checkout happens on the web (for example Shopify's checkout in a web view), pass the
client ID to it, so Angler can link the order to this app. On Shopify, add it as a cart
attribute named `_angler_client_id`:

```dart
final clientId = await Angler.getClientId();
if (clientId != null) {
  // Storefront API: `attributes` on cartCreate, or cartAttributesUpdate
  attributes.add({'key': '_angler_client_id', 'value': clientId});
}
```

It's the `client_id` every event carries: `clientId` from `configure` if you set one, otherwise
the install ID. It's null before `configure` and while `setEnabled(false)`. Read it when
checkout opens rather than caching it: `reset()` creates a new install ID.

## Check it works

Set `domain: 'dev-data.getangler.ai'` and `debugLogging: true`, then watch the native logs:
Xcode's console (subsystem `ai.getangler.analytics`) or `adb logcat -s Angler`. Look for
`queued app_launched` and `delivered … event(s)`. `HTTP 401`/`403` means the workspace ID or
token is wrong.

## Good to know

- `app_installed` means "first run with the SDK": existing users send it on their first launch
  after you add the SDK.
- The whole deep-link URL is sent as `url` on every event until the app has been in the
  background for 30 minutes. Don't forward URLs carrying secrets (OAuth codes, magic-link or
  password-reset tokens, emails); remove those parameters first.
