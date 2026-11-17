# Angler for iOS (Swift)

App events and ad-attribution signals (IDFA, click IDs) for Angler. iOS 15+, no dependencies.
Distributed with Swift Package Manager from the repo root `Package.swift`.

## Install

In Xcode: **File → Add Package Dependencies…**, enter this repository's URL, and add the
`AnglerAnalytics` product to your app target. Or in `Package.swift`:

```swift
.package(url: "https://github.com/angler-ai/angler-mobile-sdk", from: "0.1.0")
```

## Configure and track

```swift
import AnglerAnalytics

// In App.init() or application(_:didFinishLaunchingWithOptions:)
Angler.configure(AnglerConfiguration(workspaceId: "<workspace id>", token: "<workspace token>"))

Angler.track("product_viewed", data: ["productVariant": ["id": "variant-1"]])
Angler.track("level_up", properties: ["level": "2"])          // non-standard name → custom_event
Angler.track("checkout_completed", eventId: "order-123")       // your own ID, for deduplication
```

Pass `domain: "dev-data.getangler.ai"` to send to the dev environment. `track` before
`configure` is dropped with a warning; every other method works before `configure`.

## Deep links

Pass every URL that opens the app, so click IDs (`gclid`, `fbclid`, `ttclid`, …) are captured:

```swift
// SwiftUI
WindowGroup { ContentView().onOpenURL { Angler.handleDeepLink($0) } }

// UIKit (scene delegate)
func scene(_ scene: UIScene, openURLContexts contexts: Set<UIOpenURLContext>) {
    contexts.forEach { Angler.handleDeepLink($0.url) }
}
```

Universal links work the same way: pass `userActivity.webpageURL`.

## Identity, consent and opt-out

```swift
Angler.setUserId("customer-42")                         // customer_id; nil clears it
Angler.setIdentifier("appsflyer_id", value: afId)       // custom identifiers; nil removes
Angler.setApplicationTrackingEnabled(false)             // sent as application_tracking_enabled
Angler.setEnabled(false)                                // stop collecting and delete queued events
Angler.reset()                                          // e.g. on logout: new install ID
```

- **ATT:** the SDK never shows the App Tracking Transparency prompt. Your app owns it
  (`ATTrackingManager.requestTrackingAuthorization`). The SDK reads the status on every event
  and sends the IDFA only when it is `.authorized`.
- **Privacy manifest:** the package ships `PrivacyInfo.xcprivacy` (UserDefaults reason `CA92.1`,
  collected data types). It declares `NSPrivacyTracking = false`; that decision is pending
  review (design §11.1).

## What gets sent

The payload format is pinned by the shared fixtures in [`spec/`](../spec). Two behaviours to
know about:

- **The whole deep-link URL is sent** as `url` on every event until the app has been in the
  background for 30 minutes. Don't pass URLs that carry secrets (OAuth `code`, magic-link or
  password-reset tokens, emails): pass a URL with those parameters removed, or skip
  `handleDeepLink` for them.
- **`app_installed` means "first run with the SDK".** When you add the SDK to an app that's
  already published, existing users send `app_installed` on their first launch after updating.
- `app_launched` is sent when the app comes to the foreground on a cold start, or after 30+
  minutes in the background. Background-only launches (silent push, background fetch) don't
  count.
