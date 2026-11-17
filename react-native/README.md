# @angler-ai/react-native-analytics

Angler app events and ad-attribution signals for React Native (iOS and Android), over the
native Angler SDKs. React Native 0.76+ with the New Architecture.

## Install

```sh
npm install @angler-ai/react-native-analytics
cd ios && pod install
```

iOS compiles the Swift core from source inside the package (no extra pod). Android depends on
the Maven artifact `ai.getangler:analytics` at the same version.

## Configure and track

```ts
import { Angler } from '@angler-ai/react-native-analytics';

// Once at startup, e.g. in index.js or your root component's module scope.
// Calling it again (Fast Refresh) is ignored.
Angler.configure({ workspaceId: '<workspace id>', token: '<workspace token>' });

Angler.track('product_viewed', { data: { productVariant: { id: 'variant-1' } } });
Angler.track('level_up', { properties: { level: '2' } });       // non-standard name → custom_event
Angler.track('checkout_completed', { eventId: 'order-123' });    // your own ID, for deduplication
```

Options: `domain` (`dev-data.getangler.ai` for testing), `clientId`, `trackLifecycleEvents`,
`flushAt`, `flushIntervalSeconds`, `maxQueueSize`, `debugLogging`, `autoHandleDeepLinks`.

No method throws: problems are logged with `console.warn` in development. `data` that can't be
serialized (cycles, `BigInt`) is dropped and the event is still sent.

## Deep links

With `autoHandleDeepLinks` (the default), the SDK forwards the launch URL
(`Linking.getInitialURL()`) and every later `Linking` URL event. Your app still has to deliver
URLs to `Linking`, as React Native's docs describe. On iOS, add this to `AppDelegate.mm`:

```objc
#import <React/RCTLinkingManager.h>

- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url
            options:(NSDictionary<UIApplicationOpenURLOptionsKey, id> *)options
{
  return [RCTLinkingManager application:app openURL:url options:options];
}
```

To filter URLs yourself, set `autoHandleDeepLinks: false` and call `Angler.handleDeepLink(url)`.

## Identity, consent and opt-out

```ts
Angler.setUserId('customer-42');                     // customer_id; null clears it
Angler.setIdentifier('appsflyer_id', afId);          // custom identifiers; null removes
Angler.setApplicationTrackingEnabled(false);         // sent as application_tracking_enabled
Angler.setEnabled(false);                            // stop collecting and delete queued events
Angler.reset();                                      // e.g. on logout: new install ID
```

The SDK never shows the iOS ATT prompt; your app owns it (for example with
`react-native-tracking-transparency`). The IDFA is sent only when ATT is authorized. On
Android, see the core's notes on the `AD_ID` permission.

## What gets sent

- **The whole deep-link URL is sent** as `url` on every event until the app has been in the
  background for 30 minutes, and every `Linking` URL is forwarded by default. If your app
  receives URLs carrying secrets (OAuth `code`, magic-link or password-reset tokens, emails),
  set `autoHandleDeepLinks: false` and pass only cleaned URLs.
- **`app_installed` means "first run with the SDK".** When you add the SDK to an app that's
  already published, existing users send `app_installed` on their first launch after updating.
