# @anglerai/react-native-analytics

Angler app events and ad-attribution signals for React Native apps on iOS and Android. A thin
wrapper over the native Angler SDKs.

For the list of events, what the SDK collects and how delivery works, see the
[main README](https://github.com/angler-ai/angler-mobile-sdk#readme).

## Requirements

- React Native 0.76 or later with the **New Architecture** (the default since 0.76). On the old
  architecture the module doesn't load, and every call does nothing.
- iOS 15.1+, Android minSdk 24 (React Native's own minimums).
- **Expo:** works in a development build or with `expo prebuild`. Expo Go can't load native
  modules.

## Install

```sh
npm install @anglerai/react-native-analytics
cd ios && pod install
```

There's nothing else to link. iOS compiles the Swift core from source inside the package, and
Android pulls `ai.getangler:analytics` from Maven Central at the same version.

## Configure

Configure once, at startup, outside any component:

```ts
// index.js
import { Angler } from '@anglerai/react-native-analytics';

Angler.configure({
  workspaceId: '<workspace id>',
  token: '<workspace token>',
  appStoreId: 'id1234567890', // optional; sent as app_id on iOS (TikTok app events need it)
});
```

Calling `configure` again (for example on Fast Refresh) is ignored.

| Option | Default | |
|---|---|---|
| `domain` | `'data.getangler.ai'` | `'dev-data.getangler.ai'` while testing. |
| `clientId` | install ID | Overrides `client_id`. |
| `appStoreId` | none | Your App Store ID, sent as `app_id` on iOS. Android sends the package name. |
| `autoHandleDeepLinks` | `true` | Forward the launch URL and every `Linking` URL automatically. |
| `trackLifecycleEvents` | `true` | Send `app_installed` and `app_launched`. |
| `flushAt` | `20` | Queued events that trigger a send. |
| `flushIntervalSeconds` | `30` | Seconds between periodic sends. |
| `maxQueueSize` | `1000` | Oldest events are dropped beyond this. |
| `debugLogging` | `false` | Log every queued and delivered event (in the native logs). |

## Track events

```ts
import { Angler, AnglerEvent } from '@anglerai/react-native-analytics';

// Standard events; `data` is typed (AnglerData)
Angler.track(AnglerEvent.productViewed, {
  data: { productVariant: { id: 'variant-1', title: 'Linen shirt', price: { amount: 29, currencyCode: 'USD' } } },
});

Angler.track(AnglerEvent.productAddedToCart, {
  data: { cartLine: { quantity: 1, merchandise: { id: 'variant-1', price: { amount: 29, currencyCode: 'USD' } } } },
});

Angler.track(AnglerEvent.checkoutCompleted, {
  data: { checkout: { currencyCode: 'USD', totalPrice: { amount: 58, currencyCode: 'USD' } } },
  eventId: 'order-1001', // your order ID, so the purchase isn't counted twice
});

// Any other name is a custom event; properties are added to data.customData
Angler.track('wishlist_added', { properties: { product_id: 'variant-1' } });
```

`AnglerEvent` has a key per [standard event](https://github.com/angler-ai/angler-mobile-sdk#events).
`AnglerData` has one field per data object (`cart`, `cartLine`, `checkout`, `collection`,
`productVariant`, `searchResult`, `customer`, `form`, `contacts`, `customData`), and the nested
types (`AnglerCartLine`, `AnglerMoney`, …) are exported for your own code.

No method throws or returns a promise. Problems are logged with `console.warn` in development.
`data` that can't be serialized (cycles, `BigInt`) is dropped and the event is still sent.

## Deep links

With `autoHandleDeepLinks` (the default), the SDK forwards the launch URL
(`Linking.getInitialURL()`) and every later `Linking` URL event, so click IDs from ads are
captured. Your app still has to deliver URLs to `Linking`, as React Native's
[Linking docs](https://reactnative.dev/docs/linking) describe. On iOS that means, in
`AppDelegate.mm`:

```objc
#import <React/RCTLinkingManager.h>

- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url
            options:(NSDictionary<UIApplicationOpenURLOptionsKey, id> *)options
{
  return [RCTLinkingManager application:app openURL:url options:options];
}

- (BOOL)application:(UIApplication *)application continueUserActivity:(NSUserActivity *)userActivity
 restorationHandler:(void (^)(NSArray<id<UIUserActivityRestoring>> *))restorationHandler
{
  return [RCTLinkingManager application:application continueUserActivity:userActivity
                     restorationHandler:restorationHandler];
}
```

To filter URLs yourself (for example to strip tokens), set `autoHandleDeepLinks: false` and call
`Angler.handleDeepLink(url)`.

## Identity, consent and opt-out

```ts
Angler.setUserId('customer-42');                // customer_id; null clears it
Angler.setIdentifier('loyalty_id', 'L-123');    // custom identifier; null removes it
Angler.setApplicationTrackingEnabled(false);    // the user declined tracking in your app
Angler.setEnabled(false);                       // stop collecting and delete queued events
Angler.reset();                                 // on logout
Angler.flush();                                 // send the queue now
```

- **iOS tracking permission (ATT):** the SDK never shows the prompt. Request it yourself, for
  example with `react-native-tracking-transparency` or `expo-tracking-transparency`, and add
  `NSUserTrackingUsageDescription` to `Info.plist`. The IDFA is sent only once tracking is
  authorized.
- **Android advertising ID:** the library adds the `AD_ID` permission. Apps that must not use
  it remove it with `tools:node="remove"` in `AndroidManifest.xml`.
- **Firebase:** if the app uses Firebase Analytics (for example `@react-native-firebase/analytics`),
  its app instance ID is sent as `firebase_app_instance_id`. Nothing to configure.

## Web checkout

If checkout happens on the web (for example Shopify's checkout in a web view), pass the
client ID to it, so Angler can link the order to this app. On Shopify, add it as a cart
attribute named `_angler_client_id`:

```ts
const clientId = await Angler.getClientId();
if (clientId) {
  // Storefront API: `attributes` on cartCreate, or cartAttributesUpdate
  attributes.push({ key: '_angler_client_id', value: clientId });
}
```

It's the `client_id` every event carries: `clientId` from `configure` if you set one, otherwise
the install ID. It's null before `configure` and while `setEnabled(false)`. Read it when
checkout opens rather than caching it: `reset()` creates a new install ID.

## Check it works

Set `domain: 'dev-data.getangler.ai'` and `debugLogging: true`, then watch the native logs:
Xcode's console (subsystem `ai.getangler.analytics`) or `adb logcat -s Angler`. Look for
`queued app_launched` and `delivered … event(s)`. `HTTP 401`/`403` means the workspace ID or
token is wrong. If nothing is logged at all, check that the New Architecture is on and that
you rebuilt the app after installing.

## Good to know

- `app_installed` means "first run with the SDK": existing users send it on their first launch
  after you add the SDK.
- The whole deep-link URL is sent as `url` on every event until the app has been in the
  background for 30 minutes. If your app receives URLs carrying secrets (OAuth codes,
  magic-link or password-reset tokens, emails), turn off `autoHandleDeepLinks` and pass cleaned
  URLs.
