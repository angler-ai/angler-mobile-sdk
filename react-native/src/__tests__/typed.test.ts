import { readFileSync } from 'fs';
import { join } from 'path';
import type { AnglerData } from '../index';

// The shared typed-data fixture, built with the generated TypeScript types. The value of this
// test is mostly at compile time (tsc): every object below must type-check as AnglerData.
const cases: Record<string, AnglerData> = {
  cart_line_added: {
    cartLine: {
      quantity: 2,
      cost: { totalAmount: { amount: 58, currencyCode: 'USD' } },
      merchandise: {
        id: 'variant-1',
        sku: 'SKU-1',
        title: 'Blue / M',
        price: { amount: 29, currencyCode: 'USD' },
        image: { src: 'https://cdn.example.com/v1.jpg' },
        product: {
          id: 'product-1',
          title: 'Linen Shirt',
          vendor: 'Example',
          type: 'Shirts',
          url: 'https://shop.example.com/products/linen-shirt',
        },
      },
    },
  },
  checkout_with_discounts: {
    checkout: {
      token: 'chk-1',
      currencyCode: 'USD',
      totalPrice: { amount: 49.5, currencyCode: 'USD' },
      discountApplications: [
        { title: 'SUMMER', type: 'DISCOUNT_CODE', value: { percentage: 10 } },
        { title: 'Free gift', type: 'AUTOMATIC', value: { amount: 5, currencyCode: 'USD' } },
      ],
      lineItems: [
        {
          id: 'li-1',
          quantity: 1,
          title: 'Linen Shirt',
          variant: { id: 'variant-1' },
          discountAllocations: [
            {
              amount: { amount: 2.9, currencyCode: 'USD' },
              discountApplication: { title: 'SUMMER', value: { percentage: 10 } },
            },
          ],
        },
      ],
      shippingAddress: { city: 'Austin', countryCode: 'US', zip: '78701' },
    },
  },
  search_and_custom_data: {
    searchResult: { query: 'linen', productVariants: [{ id: 'variant-1' }, { id: 'variant-2' }] },
    customData: [{ name: 'source', value: 'home_banner' }],
  },
  form_submitted: {
    form: { id: 'newsletter', action: '/subscribe', elements: [{ name: 'email', type: 'email', tagName: 'INPUT' }] },
  },
};

test('typed-data fixtures', () => {
  const fixture = JSON.parse(readFileSync(join(__dirname, '../../../spec/fixtures/typed-data.json'), 'utf8'));
  expect(fixture.cases).toHaveLength(4);
  for (const c of fixture.cases) {
    expect(JSON.parse(JSON.stringify(cases[c.name]))).toEqual(c.expected);
  }
});

test('typed event names', () => {
  jest.resetModules();
  const track = jest.fn();
  jest.doMock('../NativeAnglerAnalytics', () => ({ __esModule: true, default: { track } }));
  jest.doMock('react-native', () => ({ Linking: {} }));
  const { Angler, AnglerEvent } = require('../index');
  Angler.track(AnglerEvent.productAddedToCart, { data: cases.cart_line_added });
  Angler.track('level_up');
  expect(track.mock.calls[0][0]).toBe('product_added_to_cart');
  expect(JSON.parse(track.mock.calls[0][1])).toEqual(cases.cart_line_added);
  expect(track.mock.calls[1][0]).toBe('level_up');
});

// @ts-expect-error a field that isn't in data-api's schema is a type error
const _bad: AnglerData = { cartLine: { quantity: 1, colour: 'blue' } };
void _bad;

// Call sites are typed too: an unknown nested field doesn't compile.
export function _typedCallSite(A: typeof import('../index').Angler) {
  // @ts-expect-error colour isn't a CartLine field
  A.track('product_viewed', { data: { cartLine: { colour: 'blue' } } });
}
