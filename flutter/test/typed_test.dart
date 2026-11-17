import 'dart:convert';
import 'dart:io';

import 'package:angler_analytics/angler_analytics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The shared typed-data fixture, built with the generated Dart models.
final Map<String, AnglerData> cases = {
  'cart_line_added': const AnglerData(
    cartLine: AnglerCartLine(
      quantity: 2,
      cost: AnglerCartLineCost(totalAmount: AnglerMoney(amount: 58, currencyCode: 'USD')),
      merchandise: AnglerProductVariant(
        id: 'variant-1',
        sku: 'SKU-1',
        title: 'Blue / M',
        price: AnglerMoney(amount: 29, currencyCode: 'USD'),
        image: AnglerImage(src: 'https://cdn.example.com/v1.jpg'),
        product: AnglerProduct(
          id: 'product-1',
          title: 'Linen Shirt',
          vendor: 'Example',
          type: 'Shirts',
          url: 'https://shop.example.com/products/linen-shirt',
        ),
      ),
    ),
  ),
  'checkout_with_discounts': const AnglerData(
    checkout: AnglerCheckout(
      token: 'chk-1',
      currencyCode: 'USD',
      totalPrice: AnglerMoney(amount: 49.5, currencyCode: 'USD'),
      discountApplications: [
        AnglerDiscountApplication(title: 'SUMMER', type: 'DISCOUNT_CODE', value: AnglerPricingPercentageValue(percentage: 10)),
        AnglerDiscountApplication(title: 'Free gift', type: 'AUTOMATIC', value: AnglerMoney(amount: 5, currencyCode: 'USD')),
      ],
      lineItems: [
        AnglerCheckoutLineItem(
          id: 'li-1',
          quantity: 1,
          title: 'Linen Shirt',
          variant: AnglerProductVariant(id: 'variant-1'),
          discountAllocations: [
            AnglerDiscountAllocation(
              amount: AnglerMoney(amount: 2.9, currencyCode: 'USD'),
              discountApplication: AnglerDiscountApplication(title: 'SUMMER', value: AnglerPricingPercentageValue(percentage: 10)),
            ),
          ],
        ),
      ],
      shippingAddress: AnglerMailingAddress(city: 'Austin', countryCode: 'US', zip: '78701'),
    ),
  ),
  'search_and_custom_data': const AnglerData(
    searchResult: AnglerSearchResult(query: 'linen', productVariants: [AnglerProductVariant(id: 'variant-1'), AnglerProductVariant(id: 'variant-2')]),
    customData: [AnglerCustomValue(name: 'source', value: 'home_banner')],
  ),
  'form_submitted': const AnglerData(
    form: AnglerFormElement(id: 'newsletter', action: '/subscribe', elements: [AnglerInputElement(name: 'email', type: 'email', tagName: 'INPUT')]),
  ),
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('typed-data fixtures', () {
    final fixture = jsonDecode(File('../spec/fixtures/typed-data.json').readAsStringSync()) as Map<String, dynamic>;
    final fixtureCases = fixture['cases'] as List;
    expect(fixtureCases, hasLength(4));
    for (final c in fixtureCases) {
      expect(jsonDecode(jsonEncode(cases[c['name']]!.toJson())), c['expected'], reason: c['name'] as String);
    }
  });

  test('typed track sends the event name and data JSON', () async {
    const channel = MethodChannel('ai.getangler/analytics');
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
    await Angler.track(AnglerEvent.productAddedToCart, data: cases['cart_line_added']);
    await Angler.track(const AnglerEvent.custom('level_up'), properties: {'level': '2'});
    expect(calls[0].arguments['name'], 'product_added_to_cart');
    expect(jsonDecode(calls[0].arguments['dataJson'] as String), jsonDecode(jsonEncode(cases['cart_line_added']!.toJson())));
    expect(calls[1].arguments, {'name': 'level_up', 'dataJson': null, 'propertiesJson': '{"level":"2"}', 'eventId': null});
  });
}
