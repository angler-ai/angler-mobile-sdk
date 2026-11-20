# Angler for iOS (Swift)

App events and ad-attribution signals (IDFA, click IDs) for Angler. iOS 15+, Swift 5.9+, no
dependencies. Safe to link from app extensions.

For the list of events, what the SDK collects and how delivery works, see the
[main README](../README.md).

## Install

In Xcode: **File → Add Package Dependencies…**, enter
`https://github.com/angler-ai/angler-mobile-sdk`, and add the `AnglerAnalytics` product to your
app target. Or in `Package.swift`:

```swift
.package(url: "https://github.com/angler-ai/angler-mobile-sdk", exact: "0.1.0-rc.3")
```

Release candidates need an exact version; from `0.1.0` on, `from: "0.1.0"` works.

## Configure

Configure once, as early as possible:

```swift
import AnglerAnalytics

@main
struct ShopApp: App {
    init() {
        Angler.configure(AnglerConfiguration(
            workspaceId: "<workspace id>",
            token: "<workspace token>",
            appStoreId: "id1234567890"      // optional; sent as app_id (TikTok app events need it)
        ))
    }
    var body: some Scene { WindowGroup { ContentView() } }
}
```

With UIKit, call it in `application(_:didFinishLaunchingWithOptions:)`.

| Option | Default | |
|---|---|---|
| `domain` | `"data.getangler.ai"` | `"dev-data.getangler.ai"` while testing. |
| `clientId` | install ID | Overrides `client_id`. |
| `appStoreId` | `nil` | Your App Store ID (`id1234567890` or `1234567890`), sent as `app_id`. |
| `trackLifecycleEvents` | `true` | Send `app_installed` and `app_launched`. |
| `flushAt` | `20` | Queued events that trigger a send. |
| `flushInterval` | `30` | Seconds between periodic sends. |
| `maxQueueSize` | `1000` | Oldest events are dropped beyond this. |
| `debugLogging` | `false` | Log every queued and delivered event. |

## Track events

```swift
// Standard events, with typed data objects
Angler.track(.productViewed, data: AnglerData(productVariant: AnglerProductVariant(
    id: "variant-1", price: AnglerMoney(amount: 29, currencyCode: "USD"), title: "Linen shirt"
)))

Angler.track(.productAddedToCart, data: AnglerData(cartLine: AnglerCartLine(
    merchandise: AnglerProductVariant(id: "variant-1", price: AnglerMoney(amount: 29, currencyCode: "USD")),
    quantity: 1
)))

Angler.track(.checkoutCompleted, data: AnglerData(checkout: AnglerCheckout(
    currencyCode: "USD", totalPrice: AnglerMoney(amount: 58, currencyCode: "USD")
)), eventId: "order-1001")                         // your order ID, so the purchase isn't counted twice

// Custom events; properties are added to data.customData
Angler.track(.custom("wishlist_added"), properties: ["product_id": "variant-1"])

// Untyped form: a string name and a dictionary with AnglerData's keys
Angler.track("product_viewed", data: ["productVariant": ["id": "variant-1"]])
```

`AnglerEvent` has a case per [standard event](../README.md#events). `AnglerData` has one field
per data object: `cart`, `cartLine`, `checkout`, `collection`, `productVariant`, `searchResult`,
`customer`, `form`, `contacts` and `customData`.

## Deep links

Pass every URL that opens the app, so click IDs (`gclid`, `fbclid`, `ttclid`, …) are captured:

```swift
// SwiftUI
WindowGroup { ContentView().onOpenURL { Angler.handleDeepLink($0) } }

// UIKit scene delegate: custom schemes, then universal links
func scene(_ scene: UIScene, openURLContexts contexts: Set<UIOpenURLContext>) {
    contexts.forEach { Angler.handleDeepLink($0.url) }
}
func scene(_ scene: UIScene, continue activity: NSUserActivity) {
    if let url = activity.webpageURL { Angler.handleDeepLink(url) }
}
```

For a cold start from a link in UIKit, also handle `connectionOptions.urlContexts` and
`connectionOptions.userActivities` in `scene(_:willConnectTo:options:)`.

## Identity, consent and opt-out

```swift
Angler.setUserId("customer-42")                       // customer_id; nil clears it
Angler.setIdentifier("loyalty_id", value: "L-123")    // custom identifier; nil removes it
Angler.setApplicationTrackingEnabled(false)           // the user declined tracking in your app
Angler.setEnabled(false)                              // stop collecting and delete queued events
Angler.reset()                                        // on logout
Angler.flush()                                        // send the queue now
```

- **App Tracking Transparency:** the SDK never shows the prompt. Request it yourself with
  `ATTrackingManager.requestTrackingAuthorization` (and add `NSUserTrackingUsageDescription` to
  `Info.plist`). The IDFA is sent only once the status is `.authorized`.
- **Firebase:** if the app uses Firebase Analytics, its app instance ID is sent as
  `firebase_app_instance_id`, with no Firebase dependency added. It appears once
  `FirebaseApp.configure()` has run.
- **Privacy manifest:** the package ships `PrivacyInfo.xcprivacy`, which Xcode merges into
  your app's privacy report. It lists the data types the SDK collects; include them in your App
  Store privacy details.

## Web checkout

If checkout happens on the web (for example Shopify's checkout in a web view), pass the
client ID to it, so Angler can link the order to this app. On Shopify, add it as a cart
attribute named `_angler_client_id`:

```swift
if let clientId = await Angler.getClientId() {
    // Storefront API: `attributes` on cartCreate, or cartAttributesUpdate
    attributes.append(AttributeInput(key: "_angler_client_id", value: clientId))
}
```

`Angler.getClientId { clientId in … }` does the same with a completion handler, which runs on a
background queue.

It's the `client_id` every event carries: `clientId` from `configure` if you set one, otherwise
the install ID. It's null before `configure` and while `setEnabled(false)`. Read it when
checkout opens rather than caching it: `reset()` creates a new install ID.

## Check it works

Set `domain: "dev-data.getangler.ai"` and `debugLogging: true`, run the app, and look for
`queued app_launched` and `delivered … event(s)` in the Xcode console (or Console.app,
subsystem `ai.getangler.analytics`). `HTTP 401`/`403` means the workspace ID or token is wrong.

## Good to know

- `track` before `configure` is dropped with a warning; every other call works before it.
- `app_installed` means "first run with the SDK": existing users send it on their first launch
  after you add the SDK.
- `app_launched` is sent on a cold start that reaches the foreground and after 30+ minutes in
  the background. Background-only launches (silent push, background fetch) don't count.
- Before the device is first unlocked after a reboot, configuration waits until it is, so a
  background launch at that point doesn't create a new install ID.
- The whole deep-link URL is sent as `url`. Don't pass URLs carrying secrets (OAuth codes,
  password-reset tokens, emails); remove those parameters first.
