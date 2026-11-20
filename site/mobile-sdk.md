---
title: Mobile SDK
excerpt: Send in-app events and ad-attribution signals from iOS, Android, React Native and Flutter apps.
deprecated: false
hidden: false
metadata:
  robots: index
---
# Mobile SDK

The Angler Mobile SDK sends your app's events straight to Angler, the way the Angler web pixel does on your website. It also sends the signals ad platforms need from an app: install and launch events, device details, advertising IDs (IDFA and GAID, with consent) and ad click IDs from deep links.

| Platform | Package | Install |
| --- | --- | --- |
| React Native | [`@anglerai/react-native-analytics`](https://www.npmjs.com/package/@anglerai/react-native-analytics) on npm | `npm install @anglerai/react-native-analytics@0.1.0-rc.4` |
| Flutter | [`angler_analytics`](https://pub.dev/packages/angler_analytics) on pub.dev | `angler_analytics: ^0.1.0-rc.4` |
| iOS (Swift) | `AnglerAnalytics` via Swift Package Manager | `.package(url: "https://github.com/angler-ai/angler-mobile-sdk", exact: "0.1.0-rc.4")` |
| Android (Kotlin, Java) | [`ai.getangler:analytics`](https://central.sonatype.com/artifact/ai.getangler/analytics) on Maven Central | `implementation("ai.getangler:analytics:0.1.0-rc.4")` |

All four share one version and behave the same way. The SDK is in release candidate: [let us know](mailto:support@getangler.ai) before you ship it in a production app.

## Before you start

You need your Angler **workspace ID** and a **workspace token**. Your Angler account manager can provide them, or see [Create API Access Tokens](/docs/create-api-access-tokens).

Requirements:

* **React Native:** 0.76 or later with the New Architecture (the default since 0.76). Expo works in a development build, not in Expo Go.
* **iOS:** 15.1 or later. **Android:** minSdk 24.
* The SDK includes native code, so it ships in a new App Store or Play release.

## Quick start (React Native)

Configure once at startup, outside any component, then track events as the shopper browses:

```ts
import { Angler, AnglerEvent } from '@anglerai/react-native-analytics';

Angler.configure({
  workspaceId: '<workspace id>',
  token: '<workspace token>',
  appStoreId: '<your App Store ID>', // iOS; TikTok's app events need it
});

Angler.track(AnglerEvent.productViewed, {
  data: { productVariant: { id: '41234567890', price: { amount: 29.5, currencyCode: 'USD' } } },
});
```

`app_installed` and `app_launched` are sent automatically. Then, in every app:

1. **Track the shopping events:** `product_viewed`, `collection_viewed`, `search_submitted`, `product_added_to_cart`, `cart_viewed`, `checkout_started`, `checkout_completed`, `registration_completed` and `logged_in`. Each takes a data object; the [events and data objects reference](https://github.com/angler-ai/angler-mobile-sdk/tree/main/docs) lists what to send with each, with examples in every language.
2. **On a purchase,** pass the order ID as `eventId` and in `checkout.order.id`, so it isn't counted twice.
3. **Call `Angler.setUserId('<customer id>')`** when the shopper logs in, and `Angler.reset()` when they log out.
4. **Forward deep links,** so click IDs from ads are captured. React Native does this for you through `Linking`.
5. **On iOS, show Apple's tracking prompt (ATT)** yourself if you want the IDFA sent. The SDK never shows it.

Native iOS, Android and Flutter apps follow the same steps; see the guide for your platform below.

## Web checkout and links from your website

* **Checkout on the web:** if checkout runs on your website (for example Shopify's checkout in a web view), pass `await Angler.getClientId()` to it as the cart attribute `_angler_client_id`, so the order is linked to the app.
* **"Open in app" links from your website:** add the visitor's browser IDs to the link, named after their cookies, for example `myapp://product/42?_fbp=<_fbp cookie>&_fbc=<_fbc cookie>&_ga=<_ga cookie>`. The app keeps them and sends them with every later event, so the visitor's web sessions are tied to the app. This only works when the app is already installed.

## Check it works

Add `debugLogging: true` to `configure` and watch the Xcode console or `adb logcat -s Angler` for `queued app_launched` and `delivered … event(s)`. `HTTP 401` or `403` means the workspace ID or token is wrong. To test without touching production data, add `domain: 'dev-data.getangler.ai'` and ask us for a dev workspace.

## Privacy

* Update your App Store privacy details and your Google Play data safety form. The SDK's [README](https://github.com/angler-ai/angler-mobile-sdk#what-the-sdk-collects) lists what it collects. On iOS the package ships a privacy manifest.
* `Angler.setEnabled(false)` stops collection and deletes queued events, and is remembered across launches.

## Guides and source

* [GitHub repository](https://github.com/angler-ai/angler-mobile-sdk): what the SDK collects, every event, delivery and configuration.
* Platform guides: [React Native](https://github.com/angler-ai/angler-mobile-sdk/tree/main/react-native#readme), [Flutter](https://github.com/angler-ai/angler-mobile-sdk/tree/main/flutter#readme), [iOS](https://github.com/angler-ai/angler-mobile-sdk/tree/main/ios#readme), [Android](https://github.com/angler-ai/angler-mobile-sdk/tree/main/android#readme).
* [Events and data objects](https://github.com/angler-ai/angler-mobile-sdk/tree/main/docs), with an example for every object.
* Example apps: [React Native](https://github.com/angler-ai/angler-mobile-sdk/tree/main/examples/react-native), [Flutter](https://github.com/angler-ai/angler-mobile-sdk/tree/main/examples/flutter), [iOS](https://github.com/angler-ai/angler-mobile-sdk/tree/main/examples/ios), [Android](https://github.com/angler-ai/angler-mobile-sdk/tree/main/examples/android).
* [Releases](https://github.com/angler-ai/angler-mobile-sdk/releases) and [issues](https://github.com/angler-ai/angler-mobile-sdk/issues).

Already using AppsFlyer? You can also [send AppsFlyer data to Angler](/docs/send-appsflyer-data-to-angler-via-push-api).
