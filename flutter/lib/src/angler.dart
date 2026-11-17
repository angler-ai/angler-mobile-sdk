import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'angler_configuration.dart';

/// The Angler SDK. Every method returns normally: analytics never crashes the host app.
/// Errors (no plugin, platform errors, unencodable data) are reported with [debugPrint].
class Angler {
  Angler._();

  static const MethodChannel _channel = MethodChannel('ai.getangler/analytics');

  /// Starts the SDK. Call once after `WidgetsFlutterBinding.ensureInitialized()`. A repeat
  /// call with the same workspace (e.g. after hot restart) is ignored by the native side.
  static Future<void> configure(AnglerConfiguration configuration) =>
      _invoke('configure', configuration.toMap());

  /// Queues an event. Unknown names are sent as `custom_event`. If [data] can't be encoded
  /// as JSON, the event is sent without it.
  static Future<void> track(
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
