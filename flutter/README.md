# angler_analytics

Angler app events and ad-attribution signals for Flutter (iOS and Android), over the native
Angler SDKs. Flutter 3.24+, iOS 15+, Android minSdk 21.

## Install

```yaml
dependencies:
  angler_analytics: ^0.1.0
```

iOS compiles the Swift core from source inside the plugin. Android depends on the Maven
artifact `ai.getangler:analytics` at the same version. Your iOS deployment target must be
15.0 or later (`platform :ios, '15.0'` in `ios/Podfile`).

## Configure and track

Call `WidgetsFlutterBinding.ensureInitialized()` **before** `Angler.configure`. Without it the
platform channel isn't ready, the call is ignored, and nothing is tracked.

```dart
import 'package:angler_analytics/angler_analytics.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Angler.configure(const AnglerConfiguration(workspaceId: '<workspace id>', token: '<workspace token>'));
  runApp(const MyApp());
}

// Standard events, with typed data objects (generated from data-api's schema)
await Angler.track(AnglerEvent.productAddedToCart, data: const AnglerData(
  cartLine: AnglerCartLine(
    quantity: 1,
    merchandise: AnglerProductVariant(id: 'variant-1', price: AnglerMoney(amount: 29, currencyCode: 'USD')),
  ),
));
await Angler.track(AnglerEvent.checkoutCompleted,
    data: const AnglerData(checkout: AnglerCheckout(currencyCode: 'USD', totalPrice: AnglerMoney(amount: 58, currencyCode: 'USD'))),
    eventId: 'order-123');                                      // your own ID, for deduplication

// Any other name is a custom event; properties become data.customData
await Angler.track(const AnglerEvent.custom('level_up'), properties: {'level': '2'});

// Untyped form: a string name and a JSON-like map with the same keys as AnglerData
await Angler.trackJson('product_viewed', data: {'productVariant': {'id': 'variant-1'}});
```

`AnglerEvent` lists the standard event names. `AnglerData` has one field per data object data-api
accepts: `cart`, `cartLine`, `checkout`, `collection`, `productVariant`, `searchResult`,
`customer`, `form`, `contacts` and `customData`.

Pass `domain: 'dev-data.getangler.ai'` to send to the dev environment. Hot restart re-running
`configure` is ignored.

No method throws: problems (no plugin on this platform, platform errors) are reported with
`debugPrint`. With `trackJson`, `data` that `jsonEncode` can't handle (for example a `DateTime`)
is dropped and the event is still sent.

## Deep links

Flutter has no built-in deep-link API, so forward the URLs your app receives. With
[`app_links`](https://pub.dev/packages/app_links):

```dart
final appLinks = AppLinks();
final initial = await appLinks.getInitialLink();
if (initial != null) await Angler.handleDeepLink(initial.toString());
appLinks.uriLinkStream.listen((uri) => Angler.handleDeepLink(uri.toString()));
```

Register your URL scheme on both platforms, and turn off Flutter's own deep-link handling so
`app_links` receives the links: `FlutterDeepLinkingEnabled = NO` in `ios/Runner/Info.plist`,
and `<meta-data android:name="flutter_deeplinking_enabled" android:value="false"/>` in the
Android activity.

## Identity, consent and opt-out

```dart
await Angler.setUserId('customer-42');                   // customer_id; null clears it
await Angler.setIdentifier('appsflyer_id', afId);        // custom identifiers; null removes
await Angler.setApplicationTrackingEnabled(false);       // sent as application_tracking_enabled
await Angler.setEnabled(false);                          // stop collecting and delete queued events
await Angler.reset();                                    // e.g. on logout: new install ID
```

The SDK never shows the iOS ATT prompt; your app owns it (for example with
`app_tracking_transparency`). The IDFA is sent only when ATT is authorized. On Android, apps
that must not use the advertising ID remove the `com.google.android.gms.permission.AD_ID`
permission with `tools:node="remove"`.

## What gets sent

- **The whole deep-link URL is sent** as `url` on every event until the app has been in the
  background for 30 minutes. Don't forward URLs that carry secrets (OAuth `code`, magic-link or
  password-reset tokens, emails): remove those parameters first, or skip them.
- **`app_installed` means "first run with the SDK".** When you add the SDK to an app that's
  already published, existing users send `app_installed` on their first launch after updating.
