import 'package:angler_analytics/angler_analytics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('ai.getangler/analytics');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> calls;

  setUp(() {
    calls = [];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
  });

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('configure sends map with wrapper and without nulls', () async {
    await Angler.configure(const AnglerConfiguration(workspaceId: 'ws', token: 't'));
    expect(calls.single.method, 'configure');
    expect(calls.single.arguments, {'workspaceId': 'ws', 'token': 't', 'wrapper': 'flutter'});
  });

  test('configure passes optional fields', () async {
    await Angler.configure(const AnglerConfiguration(
        workspaceId: 'ws', token: 't', domain: 'dev-data.getangler.ai', flushAt: 5, debugLogging: true));
    expect(calls.single.arguments, {
      'workspaceId': 'ws',
      'token': 't',
      'domain': 'dev-data.getangler.ai',
      'flushAt': 5,
      'debugLogging': true,
      'wrapper': 'flutter',
    });
  });

  test('track encodes data and properties as JSON', () async {
    await Angler.track('product_viewed', data: {'productVariant': {'id': 'v1'}}, properties: {'a': '1'});
    expect(calls.single.method, 'track');
    expect(calls.single.arguments, {
      'name': 'product_viewed',
      'dataJson': '{"productVariant":{"id":"v1"}}',
      'propertiesJson': '{"a":"1"}',
      'eventId': null,
    });
  });

  test('track without data or properties sends nulls', () async {
    await Angler.track('purchase', eventId: 'order-1');
    expect(calls.single.arguments, {'name': 'purchase', 'dataJson': null, 'propertiesJson': null, 'eventId': 'order-1'});
  });

  test('unencodable data is dropped, event still sent', () async {
    await Angler.track('x', data: {'when': DateTime(2026)});
    expect(calls.single.arguments['dataJson'], isNull);
    expect(calls.single.arguments['name'], 'x');
  });

  test('other methods use the documented channel arguments', () async {
    await Angler.handleDeepLink('myapp://x?gclid=g');
    await Angler.setUserId(null);
    await Angler.setIdentifier('appsflyer_id', 'af-1');
    await Angler.setApplicationTrackingEnabled(false);
    await Angler.setEnabled(true);
    await Angler.flush();
    await Angler.reset();
    expect(calls.map((c) => [c.method, c.arguments]).toList(), [
      ['handleDeepLink', {'url': 'myapp://x?gclid=g'}],
      ['setUserId', {'userId': null}],
      ['setIdentifier', {'name': 'appsflyer_id', 'value': 'af-1'}],
      ['setApplicationTrackingEnabled', {'enabled': false}],
      ['setEnabled', {'enabled': true}],
      ['flush', null],
      ['reset', null],
    ]);
  });

  test('PlatformException is swallowed', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'boom');
    });
    await expectLater(Angler.flush(), completes);
    await expectLater(Angler.track('x'), completes);
  });

  test('MissingPluginException is swallowed', () async {
    messenger.setMockMethodCallHandler(channel, null);
    await expectLater(Angler.configure(const AnglerConfiguration(workspaceId: 'ws', token: 't')), completes);
    await expectLater(Angler.flush(), completes);
  });
}
