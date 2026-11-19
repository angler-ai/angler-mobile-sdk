// Hand-written content for docs/: the examples and the notes the schema doesn't carry.
// scripts/generate-docs.mjs combines it with the schema snapshot. Examples are the JSON the SDK
// sends; the generator validates them against the schema and renders them in every language.

/** Each data object (a field of AnglerData), the events it's sent with, and its example. */
export const dataFields = {
  productVariant: {
    events: ['product_viewed'],
    example: {
      id: '41234567890',
      title: 'Blue / M',
      sku: 'LS-BLU-M',
      price: { amount: 29.5, currencyCode: 'USD' },
      image: { src: 'https://cdn.example.com/linen-shirt-blue.jpg' },
      product: {
        id: '7012345678',
        title: 'Linen Shirt',
        vendor: 'Example Co',
        type: 'Shirts',
        url: '/products/linen-shirt',
      },
      inventoryItem: { id: '43210987654', cost: { amount: 12, currencyCode: 'USD' } },
    },
  },
  collection: {
    events: ['collection_viewed'],
    example: {
      id: '289012345',
      title: 'Summer',
      productVariants: [
        { id: '41234567890', title: 'Blue / M', price: { amount: 29.5, currencyCode: 'USD' } },
        { id: '41234567891', title: 'White / M', price: { amount: 29.5, currencyCode: 'USD' } },
      ],
    },
  },
  searchResult: {
    events: ['search_submitted'],
    example: {
      query: 'linen',
      productVariants: [{ id: '41234567890' }, { id: '41234567891' }],
    },
  },
  cartLine: {
    events: ['product_added_to_cart', 'product_removed_from_cart'],
    example: {
      quantity: 2,
      cost: { totalAmount: { amount: 59, currencyCode: 'USD' } },
      merchandise: {
        id: '41234567890',
        title: 'Blue / M',
        sku: 'LS-BLU-M',
        price: { amount: 29.5, currencyCode: 'USD' },
        product: { id: '7012345678', title: 'Linen Shirt' },
      },
    },
  },
  cart: {
    events: ['cart_viewed'],
    example: {
      id: 'c1-7d3e9a',
      totalQuantity: 3,
      cost: { totalAmount: { amount: 79, currencyCode: 'USD' } },
      lines: [
        {
          quantity: 2,
          cost: { totalAmount: { amount: 59, currencyCode: 'USD' } },
          merchandise: { id: '41234567890', title: 'Blue / M', price: { amount: 29.5, currencyCode: 'USD' } },
        },
        {
          quantity: 1,
          cost: { totalAmount: { amount: 20, currencyCode: 'USD' } },
          merchandise: { id: '41234567999', title: 'Default', price: { amount: 20, currencyCode: 'USD' } },
        },
      ],
    },
  },
  checkout: {
    events: [
      'checkout_started',
      'checkout_contact_info_submitted',
      'checkout_address_info_submitted',
      'checkout_shipping_info_submitted',
      'payment_info_submitted',
      'checkout_completed',
    ],
    exampleEvent: 'checkout_completed',
    eventId: '5123456789012',
    example: {
      token: 'chk-9f2c41',
      currencyCode: 'USD',
      email: 'jane@example.com',
      phone: '+15555550123',
      order: { id: '5123456789012' },
      lineItems: [
        {
          id: 'li-1',
          quantity: 2,
          title: 'Linen Shirt',
          variant: {
            id: '41234567890',
            title: 'Blue / M',
            sku: 'LS-BLU-M',
            price: { amount: 29.5, currencyCode: 'USD' },
            product: { id: '7012345678', title: 'Linen Shirt' },
          },
          discountAllocations: [
            {
              amount: { amount: 5.9, currencyCode: 'USD' },
              discountApplication: { title: 'SUMMER10', type: 'DISCOUNT_CODE', value: { percentage: 10 } },
            },
          ],
        },
        {
          id: 'li-2',
          quantity: 1,
          title: 'Coffee Beans',
          variant: { id: '41234567999', price: { amount: 20, currencyCode: 'USD' } },
          sellingPlanAllocation: { sellingPlan: { id: '690012', name: 'Delivered every 2 weeks' } },
        },
      ],
      discountApplications: [
        {
          allocationMethod: 'ACROSS',
          targetSelection: 'ALL',
          targetType: 'LINE_ITEM',
          title: 'SUMMER10',
          type: 'DISCOUNT_CODE',
          value: { percentage: 10 },
        },
      ],
      subtotalPrice: { amount: 73.1, currencyCode: 'USD' },
      shippingLine: { price: { amount: 5, currencyCode: 'USD' } },
      totalTax: { amount: 6.03, currencyCode: 'USD' },
      totalPrice: { amount: 84.13, currencyCode: 'USD' },
      shippingAddress: {
        firstName: 'Jane',
        lastName: 'Doe',
        address1: '1 Main St',
        city: 'Austin',
        province: 'Texas',
        provinceCode: 'TX',
        country: 'United States',
        countryCode: 'US',
        zip: '78701',
      },
      attributes: [{ key: 'gift_message', value: 'Happy birthday!' }],
    },
  },
  form: {
    events: ['form_submitted'],
    example: {
      id: 'newsletter',
      action: '/contact#newsletter',
      elements: [{ id: 'newsletter-email', name: 'contact[email]', tagName: 'INPUT', type: 'email', value: 'jane@example.com' }],
    },
  },
  customer: {
    events: ['registration_completed', 'logged_in'],
    example: {
      id: '6012345678',
      email: 'jane@example.com',
      phone: '+15555550123',
      firstName: 'Jane',
      lastName: 'Doe',
      ordersCount: 3,
    },
  },
  contacts: {
    events: [],
    exampleEvent: 'form_submitted',
    example: [{ email: 'sam@example.com', firstName: 'Sam' }],
  },
  customData: {
    events: [],
    exampleEvent: 'wishlist_added',
    example: [
      { name: 'wishlist_id', value: 'w-123' },
      { name: 'source', value: 'home_banner' },
    ],
  },
};

/** The events in the order the index lists them: roughly a shopper's path. */
export const eventOrder = [
  'app_installed',
  'app_launched',
  'page_viewed',
  'product_viewed',
  'collection_viewed',
  'search_submitted',
  'product_added_to_cart',
  'product_removed_from_cart',
  'cart_viewed',
  'checkout_started',
  'checkout_contact_info_submitted',
  'checkout_address_info_submitted',
  'checkout_shipping_info_submitted',
  'payment_info_submitted',
  'checkout_completed',
  'form_submitted',
  'registration_completed',
  'logged_in',
];

/** The `properties` shortcut on the customData page; the same pairs as customData's example. */
export const propertiesExample = {
  event: 'wishlist_added',
  properties: { wishlist_id: 'w-123', source: 'home_banner' },
};

/** Examples for union members a data object example doesn't reach, by union name. */
export const unionExamples = {
  DiscountApplicationValue: [{ percentage: 10 }, { amount: 5, currencyCode: 'USD' }],
};

/** Shown under each type's title, before its fields. */
export const typeNotes = {
  Data:
    "An event's data: the commerce objects it refers to, plus your own name/value pairs. Every " +
    'field is optional; set the ones that fit the event and leave out the rest.',
  Cart: 'The shopper\'s cart, sent with `cart_viewed`.',
  Checkout:
    'A checkout, from `checkout_started` through `checkout_completed`. On `checkout_completed`, ' +
    'set `order.id` and `totalPrice`, and pass the order ID as `eventId` too, so the purchase ' +
    "isn't counted twice.",
  Attribute: 'A custom key/value pair on the checkout, such as a gift message.',
  Order: 'The order a completed checkout created.',
  ShippingRate: 'The shipping rate chosen at checkout.',
  Collection: 'A collection or category the shopper viewed, sent with `collection_viewed`.',
  SearchResult: 'A search the shopper ran, sent with `search_submitted`.',
  Customer:
    'A customer: the signed-in shopper, or someone who just registered. Email, phone, name and ' +
    'ID help match app activity to ad clicks, so send what you have.',
  FormElement: 'A form the shopper submitted, sent with `form_submitted`.',
  InputElement: 'One input of a submitted form.',
  CustomValue: 'A name/value pair of your own. Both are strings.',
  ProductVariant:
    'A product variant (the thing a shopper buys: a size or color of a product). Use the same ' +
    'ID as your product catalog (on Shopify, the variant ID) so ad platforms can match it.',
  Money: 'An amount of money and its currency.',
  MailingAddress: 'A shipping or billing address.',
  CheckoutLineItem: 'One line of a checkout: a variant, its quantity and any discounts on it.',
  PricingPercentageValue: 'A discount given as a percentage.',
  Image: 'An image of the product variant (or of the product, if the variant has none).',
  DiscountApplicationValue:
    'The value of a discount: a percentage (`AnglerPricingPercentageValue`) or a fixed amount ' +
    '(`AnglerMoney`).',
};

/** Field notes: replace the schema's description when it has none, otherwise follow it. */
export const fieldNotes = {
  'Data.cart': { text: 'The cart, for `cart_viewed`.' },
  'Data.cartLine': { text: 'The line added or removed, for `product_added_to_cart` and `product_removed_from_cart`.' },
  'Data.checkout': { text: 'The checkout, for the checkout events and `payment_info_submitted`.' },
  'Data.collection': { text: 'The collection viewed, for `collection_viewed`.' },
  'Data.productVariant': { text: 'The variant viewed, for `product_viewed`.' },
  'Data.searchResult': { text: 'The search, for `search_submitted`.' },
  'Data.customer': { text: 'The customer, for `registration_completed` and `logged_in`.' },
  'Data.form': { text: 'The form, for `form_submitted`.' },
  'Data.contacts': { text: 'Other people the event refers to, in the same shape as `customer`.' },
  'Data.customData': {
    text:
      "Your own name/value pairs; a custom event's details go here. `track`'s `properties` " +
      'argument adds to it.',
  },
  'Cart.lines': { text: 'The lines in the cart.' },
  'Checkout.order': { text: 'The order the checkout created. Set it on `checkout_completed`.' },
  'Checkout.shippingLine': { text: 'The shipping rate chosen.' },
  'Checkout.totalPrice': { text: 'Sent to ad platforms as the purchase value.', append: true },
  'Checkout.phone': { text: 'E.164 format, for example `+15555550123`.', append: true },
  'Attribute.key': { text: "The attribute's name." },
  'Attribute.value': { text: "The attribute's value." },
  'Collection.productVariants': { text: 'The variants shown in the collection; the first page is enough.' },
  'SearchResult.productVariants': { text: 'The variants the search returned; the first page is enough.' },
  'FormElement.elements': { text: "The form's inputs." },
  'CustomValue.name': { text: 'The name.' },
  'CustomValue.value': { text: 'The value, as a string.' },
  'Money.amount': { text: 'In the currency\'s main unit: `29.99`, not `2999`.', append: true },
  'Money.currencyCode': { text: 'An ISO 4217 code, for example `USD`.', append: true },
  'ProductVariant.id': { text: 'Use the same ID as your product catalog.', append: true },
};
