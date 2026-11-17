# Angler for Android (Kotlin and Java)

App events and ad-attribution signals (GAID, click IDs, Play Install Referrer) for Angler.
minSdk 21. Maven coordinates `ai.getangler:analytics`.

## Install

```kotlin
dependencies {
    implementation("ai.getangler:analytics:0.1.0")
}
```

## Configure and track

```kotlin
class MyApp : Application() {
    override fun onCreate() {
        super.onCreate()
        Angler.configure(this, AnglerConfiguration(workspaceId = "<workspace id>", token = "<workspace token>"))
    }
}

// Standard events, with typed data objects (generated from data-api's schema)
Angler.track(AnglerEvent.ProductAddedToCart, AnglerData(cartLine = AnglerCartLine(
    merchandise = AnglerProductVariant(id = "variant-1", price = AnglerMoney(amount = 29, currencyCode = "USD")),
    quantity = 1,
)))
Angler.track(
    AnglerEvent.CheckoutCompleted,
    AnglerData(checkout = AnglerCheckout(currencyCode = "USD", totalPrice = AnglerMoney(amount = 58, currencyCode = "USD"))),
    eventId = "order-123",                                       // your own ID, for deduplication
)

// Any other name is a custom event; properties become data.customData
Angler.track(AnglerEvent.Custom("level_up"), properties = mapOf("level" to "2"))

// Untyped form: a string name and a map with the same keys as AnglerData
Angler.track("product_viewed", mapOf("productVariant" to mapOf("id" to "variant-1")))
```

`AnglerEvent` lists the standard event names. `AnglerData` has one field per data object data-api
accepts: `cart`, `cartLine`, `checkout`, `collection`, `productVariant`, `searchResult`,
`customer`, `form`, `contacts` and `customData`.

From Java:

```java
Angler.configure(this, new AnglerConfiguration("<workspace id>", "<workspace token>"));
Angler.track(AnglerEvent.ProductViewed.INSTANCE, new AnglerData(null, null, null, null,
    new AnglerProductVariant("variant-1")));
Angler.track("product_viewed", dataMap);     // or the untyped form
```

Pass `domain = "dev-data.getangler.ai"` to send to the dev environment. `track` before
`configure` is dropped with a warning; other calls made before `configure` are applied when it
runs.

## Deep links

Pass every URL that opens an activity, so click IDs (`gclid`, `fbclid`, `ttclid`, …) are
captured:

```kotlin
override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    if (savedInstanceState == null) intent?.data?.let { Angler.handleDeepLink(it) }
}

override fun onNewIntent(intent: Intent) {
    super.onNewIntent(intent)
    intent.data?.let { Angler.handleDeepLink(it) }
}
```

On a first install the SDK also reads the **Play Install Referrer** (up to 5 s), stores its click
IDs and sends the raw string as `referrer` on `app_installed`.

## Identity, consent and opt-out

```kotlin
Angler.setUserId("customer-42")                    // customer_id; null clears it
Angler.setIdentifier("appsflyer_id", afId)         // custom identifiers; null removes
Angler.setApplicationTrackingEnabled(false)        // sent as application_tracking_enabled
Angler.setEnabled(false)                           // stop collecting and delete queued events
Angler.reset()                                     // e.g. on logout: new install ID
```

- **GAID:** read off the main thread at configure and on each new session. Not sent when
  limit-ad-tracking is on or Play services are missing.
- **`AD_ID` permission:** the library declares `com.google.android.gms.permission.AD_ID`. Apps
  that must not use the advertising ID (for example, apps for children) remove it:

  ```xml
  <uses-permission android:name="com.google.android.gms.permission.AD_ID" tools:node="remove" />
  ```

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
  minutes in the background. Background-only starts (FCM, WorkManager, broadcast receivers)
  don't count.
