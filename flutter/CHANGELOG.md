## 0.1.0-rc.4

- Deep links can carry browser IDs (`fbp`, `fbc`, `ga`, `ttp`, `scid`, `pin_unauth`,
  `rdt_uuid`) so app events can be tied to the web visitor. Like click IDs, they're stored and
  sent on every later event. Parameter names may start with `_` (`_fbp`), as the cookies do.

## 0.1.0-rc.3

- No changes to the Flutter package. Released so the React Native package, which failed to
  publish as 0.1.0-rc.2, ships `getClientId()`.

## 0.1.0-rc.2

- `Angler.getClientId()`: the `client_id` events are sent with, to pass to a web checkout (for
  example as a cart attribute) so Angler can link it to the app.

## 0.1.0-rc.1

- First release candidate: event tracking, lifecycle events, persistent queue, device properties,
  IDFA/GAID with consent flags, click-ID capture from deep links (and the Play Install
  Referrer on Android), user and custom identifiers, opt-out, typed events and data, the
  Firebase app instance ID, and the `app_id` device property.
