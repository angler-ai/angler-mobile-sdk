# Angler for Android (Kotlin and Java)

App events and ad-attribution signals (GAID, click IDs, Play Install Referrer) for Angler.
minSdk 21, callable from Kotlin and Java.

For the list of events, what the SDK collects and how delivery works, see the
[main README](../README.md).

## Install

The library is on Maven Central:

```kotlin
dependencies {
    implementation("ai.getangler:analytics:0.1.0-rc.1")
}
```

It brings in Play services' advertising-ID client, the Play Install Referrer library and
`androidx.lifecycle`, and adds the `INTERNET` and `AD_ID` permissions.

## Configure

Configure in `Application.onCreate`, so events from every entry point (activities, push,
background work) are captured:

```kotlin
class ShopApp : Application() {
    override fun onCreate() {
        super.onCreate()
        Angler.configure(this, AnglerConfiguration(workspaceId = "<workspace id>", token = "<workspace token>"))
    }
}
```

| Option | Default | |
|---|---|---|
| `domain` | `"data.getangler.ai"` | `"dev-data.getangler.ai"` while testing. |
| `clientId` | install ID | Overrides `client_id`. |
| `appId` | package name | Sent as the `app_id` device property. |
| `trackLifecycleEvents` | `true` | Send `app_installed` and `app_launched`. |
| `flushAt` | `20` | Queued events that trigger a send. |
| `flushIntervalSeconds` | `30` | Seconds between periodic sends. |
| `maxQueueSize` | `1000` | Oldest events are dropped beyond this. |
| `debugLogging` | `false` | Log every queued and delivered event. |

## Track events

```kotlin
// Standard events, with typed data objects
Angler.track(AnglerEvent.ProductViewed, AnglerData(productVariant = AnglerProductVariant(
    id = "variant-1", title = "Linen shirt", price = AnglerMoney(amount = 29, currencyCode = "USD"),
)))

Angler.track(AnglerEvent.ProductAddedToCart, AnglerData(cartLine = AnglerCartLine(
    merchandise = AnglerProductVariant(id = "variant-1", price = AnglerMoney(amount = 29, currencyCode = "USD")),
    quantity = 1,
)))

Angler.track(
    AnglerEvent.CheckoutCompleted,
    AnglerData(checkout = AnglerCheckout(currencyCode = "USD", totalPrice = AnglerMoney(amount = 58, currencyCode = "USD"))),
    eventId = "order-1001",                        // your order ID, so the purchase isn't counted twice
)

// Custom events; properties are added to data.customData
Angler.track(AnglerEvent.Custom("wishlist_added"), properties = mapOf("product_id" to "variant-1"))

// Untyped form: a string name and a map with AnglerData's keys
Angler.track("product_viewed", mapOf("productVariant" to mapOf("id" to "variant-1")))
```

`AnglerEvent` has an object per [standard event](../README.md#events). `AnglerData` has one
field per data object: `cart`, `cartLine`, `checkout`, `collection`, `productVariant`,
`searchResult`, `customer`, `form`, `contacts` and `customData`.

From Java, every method is static and the data classes have overloaded constructors:

```java
Angler.configure(this, new AnglerConfiguration("<workspace id>", "<workspace token>"));
Angler.track(AnglerEvent.ProductViewed.INSTANCE);
Angler.track(new AnglerEvent.Custom("wishlist_added"), null, Collections.singletonMap("product_id", "variant-1"));
Angler.track("product_viewed", Collections.singletonMap("productVariant", Collections.singletonMap("id", "variant-1")));
```

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

On a first install the SDK also reads the **Play Install Referrer** (waiting up to 5 seconds),
stores its click IDs and sends the raw referrer as `referrer` on `app_installed`. Nothing to set
up.

## Identity, consent and opt-out

```kotlin
Angler.setUserId("customer-42")                   // customer_id; null clears it
Angler.setIdentifier("loyalty_id", "L-123")       // custom identifier; null removes it
Angler.setApplicationTrackingEnabled(false)       // the user declined tracking in your app
Angler.setEnabled(false)                          // stop collecting and delete queued events
Angler.reset()                                    // on logout
Angler.flush()                                    // send the queue now
```

- **GAID:** read off the main thread at configure and at each new session. Not sent when the
  user opted out of ad personalization or Play services are missing.
- **`AD_ID` permission:** the library declares `com.google.android.gms.permission.AD_ID`. Apps
  that must not use the advertising ID (for example, apps for children) remove it in their
  manifest:

  ```xml
  <uses-permission android:name="com.google.android.gms.permission.AD_ID" tools:node="remove" />
  ```
- **Firebase:** if the app includes Firebase Analytics, its app instance ID is sent as
  `firebase_app_instance_id`, with no Firebase dependency added. The library's R8 rules keep
  the two Firebase methods it calls, so minified builds work too.
- **Play data safety:** declare the data types listed in the
  [main README](../README.md#what-the-sdk-collects) (device IDs, app interactions) in your Play
  Console data safety form.

## Check it works

Set `domain = "dev-data.getangler.ai"` and `debugLogging = true`, run the app, and watch
`adb logcat -s Angler` for `queued app_launched` and `delivered … event(s)`. `HTTP 401`/`403`
means the workspace ID or token is wrong.

## Good to know

- `track` before `configure` is dropped with a warning; other calls made before `configure` are
  applied when it runs.
- `app_installed` means "first run with the SDK": existing users send it on their first launch
  after you add the SDK.
- `app_launched` is sent when the app comes to the foreground on a cold start and after 30+
  minutes in the background. Background-only starts (FCM, WorkManager, broadcast receivers)
  don't count.
- The whole deep-link URL is sent as `url`. Don't pass URLs carrying secrets (OAuth codes,
  password-reset tokens, emails); remove those parameters first.
