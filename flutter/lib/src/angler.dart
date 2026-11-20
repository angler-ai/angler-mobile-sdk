import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'angler_configuration.dart';
import 'models.generated.dart';

/// The Angler SDK. Every method returns normally: analytics never crashes the host app.
/// Errors (no plugin, platform errors, unencodable data) are reported with [debugPrint].
class Angler {
  Angler._();

  static const MethodChannel _channel = MethodChannel('ai.getangler/analytics');

  /// Starts the SDK. Call once after `WidgetsFlutterBinding.ensureInitialized()`. A repeat
  /// call with the same workspace (e.g. after hot restart) is ignored by the native side.
  static Future<void> configure(AnglerConfiguration configuration) =>
      _invoke('configure', configuration.toMap());

  /// Queues an event: a standard name (`AnglerEvent.productAddedToCart`) or
  /// `AnglerEvent.custom('name')`, with typed [data].
  ///
  /// ```dart
  /// await Angler.track(AnglerEvent.productAddedToCart, data: const AnglerData(
  ///   cartLine: AnglerCartLine(quantity: 1, merchandise: AnglerProductVariant(id: 'variant-1')),
  /// ));
  /// ```
  static Future<void> track(
    AnglerEvent event, {
    AnglerData? data,
    Map<String, String>? properties,
    String? eventId,
  }) {
    Map<String, Object?>? json;
    try {
      json = data?.toJson();
    } catch (e) {
      debugPrint('[Angler] data could not be converted; sending the event without it ($e)');
    }
    return trackJson(event.name, data: json, properties: properties, eventId: eventId);
  }

  /// Like [track], with the event name as a string and [data] as a JSON-like map (the same
  /// top-level keys as [AnglerData]). If [data] can't be encoded as JSON, the event is sent
  /// without it.
  static Future<void> trackJson(
    String name, {
    Map<String, Object?>? data,
    Map<String, String>? properties,
    String? eventId,
  }) =>
      _invoke('track', {
        'name': name,
        'dataJson': (data == null || data.isEmpty) ? null : _encode(data, 'data'),
        'propertiesJson': (properties == null || properties.isEmpty) ? null : _encode(properties, 'properties'),
        'eventId': eventId,
      });

  /// Captures click IDs and the session URL. Flutter has no built-in deep-link API: pass the
  /// URLs your app receives (for example from the `app_links` package).
  static Future<void> handleDeepLink(String url) => _invoke('handleDeepLink', {'url': url});

  /// Sets the `customer_id` identifier; null clears it.
  static Future<void> setUserId(String? userId) => _invoke('setUserId', {'userId': userId});

  /// Sets a custom identifier such as `appsflyer_id`; null removes it.
  static Future<void> setIdentifier(String name, String? value) =>
      _invoke('setIdentifier', {'name': name, 'value': value});

  static Future<void> setApplicationTrackingEnabled(bool enabled) =>
      _invoke('setApplicationTrackingEnabled', {'enabled': enabled});

  /// `false` stops all collection and deletes queued events.
  static Future<void> setEnabled(bool enabled) => _invoke('setEnabled', {'enabled': enabled});

  /// Sends queued events now.
  static Future<void> flush() => _invoke('flush');

  /// Clears the user ID, custom identifiers and attribution, and creates a new install ID.
  static Future<void> reset() => _invoke('reset');

  /// The `client_id` events are sent with: `clientId` from [configure] if you set one, otherwise
  /// the install ID. Pass it to something the app hands off to, such as a web checkout (as a cart
  /// attribute), so Angler can link what happens there to this app. Null before [configure],
  /// while `setEnabled(false)`, and if the call fails. [reset] creates a new install ID, so read
  /// it when you need it rather than caching it.
  static Future<String?> getClientId() async {
    try {
      return await _channel.invokeMethod<String>('getClientId');
    } on MissingPluginException {
      debugPrint('[Angler] getClientId: no native plugin on this platform; returning null');
    } catch (e) {
      debugPrint('[Angler] getClientId failed: $e');
    }
    return null;
  }

  static String? _encode(Object value, String what) {
    try {
      return jsonEncode(value);
    } catch (e) {
      debugPrint('[Angler] $what is not JSON-encodable; sending the event without it ($e)');
      return null;
    }
  }

  static Future<void> _invoke(String method, [Object? arguments]) async {
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } on MissingPluginException {
      debugPrint('[Angler] $method: no native plugin on this platform; ignored');
    } catch (e) {
      debugPrint('[Angler] $method failed: $e');
    }
  }
}
