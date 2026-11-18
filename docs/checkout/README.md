# AnglerCheckout

A checkout, from `checkout_started` through `checkout_completed`. On `checkout_completed`, set `order.id` and `totalPrice`, and pass the order ID as `eventId` too, so the purchase isn't counted twice.

Sent as `data.checkout`. Usually sent with `checkout_started`, `checkout_contact_info_submitted`, `checkout_address_info_submitted`, `checkout_shipping_info_submitted`, `payment_info_submitted`, `checkout_completed`.

[All data objects](../README.md)

## Fields

Every field is optional unless it says **Required**. Leave out what you don't have.

| Field | Type | Description |
|---|---|---|
| `attributes` | list of [AnglerAttribute](../attribute/README.md) | A list of attributes accumulated throughout the checkout process. |
| `billingAddress` | [AnglerMailingAddress](../mailing-address/README.md) | An address. |
| `currencyCode` | string | The three-letter code that represents the currency, for example, USD. Supported codes include standard ISO 4217 codes, legacy codes, and non-standard codes. |
| `discountApplications` | list of [AnglerDiscountApplication](../discount-application/README.md) | A list of discount applications. |
| `email` | string | The email attached to this checkout. |
| `hashedEmail` | string | Hashed value of email in SHA256 (lower case). |
| `lineItems` | list of [AnglerCheckoutLineItem](../checkout-line-item/README.md) | A list of line item objects, each one containing information about an item in the checkout. |
| `order` | [AnglerOrder](../order/README.md) | The order the checkout created. Set it on `checkout_completed`. |
| `phone` | string | A unique phone number for the customer. E.164 format, for example `+15555550123`. |
| `hashedPhone` | string | Hashed value of phone in SHA256 (lower case). |
| `shippingAddress` | [AnglerMailingAddress](../mailing-address/README.md) | An address. |
| `shippingLine` | [AnglerShippingRate](../shipping-rate/README.md) | The shipping rate chosen. |
| `subtotalPrice` | [AnglerMoney](../money/README.md) | A monetary value with currency. |
| `token` | string | A unique identifier for a particular checkout. |
| `totalPrice` | [AnglerMoney](../money/README.md) | A monetary value with currency. Sent to ad platforms as the purchase value. |
| `totalTax` | [AnglerMoney](../money/README.md) | A monetary value with currency. |

## Example

**Swift**

```swift
Angler.track(
    .checkoutCompleted,
    data: AnglerData(
        checkout: AnglerCheckout(
            attributes: [AnglerAttribute(key: "gift_message", value: "Happy birthday!")],
            currencyCode: "USD",
            discountApplications: [
                AnglerDiscountApplication(
                    allocationMethod: "ACROSS",
                    targetSelection: "ALL",
                    targetType: "LINE_ITEM",
                    title: "SUMMER10",
                    type: "DISCOUNT_CODE",
                    value: .pricingPercentageValue(AnglerPricingPercentageValue(percentage: 10))
                )
            ],
            email: "jane@example.com",
            lineItems: [
                AnglerCheckoutLineItem(
                    discountAllocations: [
                        AnglerDiscountAllocation(
                            amount: AnglerMoney(amount: 5.9, currencyCode: "USD"),
                            discountApplication: AnglerDiscountApplication(
                                title: "SUMMER10",
                                type: "DISCOUNT_CODE",
                                value: .pricingPercentageValue(AnglerPricingPercentageValue(
                                    percentage: 10
                                ))
                            )
                        )
                    ],
                    id: "li-1",
                    quantity: 2,
                    title: "Linen Shirt",
                    variant: AnglerProductVariant(
                        id: "41234567890",
                        price: AnglerMoney(amount: 29.5, currencyCode: "USD"),
                        product: AnglerProduct(id: "7012345678", title: "Linen Shirt"),
                        sku: "LS-BLU-M",
                        title: "Blue / M"
                    )
                ),
                AnglerCheckoutLineItem(
                    id: "li-2",
                    quantity: 1,
                    sellingPlanAllocation: AnglerSellingPlanAllocation(
                        sellingPlan: AnglerSellingPlan(
                            id: "690012",
                            name: "Delivered every 2 weeks"
                        )
                    ),
                    title: "Coffee Beans",
                    variant: AnglerProductVariant(
                        id: "41234567999",
                        price: AnglerMoney(amount: 20, currencyCode: "USD")
                    )
                )
            ],
            order: AnglerOrder(id: "5123456789012"),
            phone: "+15555550123",
            shippingAddress: AnglerMailingAddress(
                address1: "1 Main St",
                city: "Austin",
                country: "United States",
                countryCode: "US",
                firstName: "Jane",
                lastName: "Doe",
                province: "Texas",
                provinceCode: "TX",
                zip: "78701"
            ),
            shippingLine: AnglerShippingRate(price: AnglerMoney(amount: 5, currencyCode: "USD")),
            subtotalPrice: AnglerMoney(amount: 73.1, currencyCode: "USD"),
            token: "chk-9f2c41",
            totalPrice: AnglerMoney(amount: 84.13, currencyCode: "USD"),
            totalTax: AnglerMoney(amount: 6.03, currencyCode: "USD")
        )
    ),
    eventId: "5123456789012"
)
```

**Kotlin**

```kotlin
Angler.track(
    AnglerEvent.CheckoutCompleted,
    AnglerData(
        checkout = AnglerCheckout(
            attributes = listOf(AnglerAttribute(key = "gift_message", value = "Happy birthday!")),
            currencyCode = "USD",
            discountApplications = listOf(
                AnglerDiscountApplication(
                    allocationMethod = "ACROSS",
                    targetSelection = "ALL",
                    targetType = "LINE_ITEM",
                    title = "SUMMER10",
                    type = "DISCOUNT_CODE",
                    value = AnglerPricingPercentageValue(percentage = 10),
                ),
            ),
            email = "jane@example.com",
            lineItems = listOf(
                AnglerCheckoutLineItem(
                    discountAllocations = listOf(
                        AnglerDiscountAllocation(
                            amount = AnglerMoney(amount = 5.9, currencyCode = "USD"),
                            discountApplication = AnglerDiscountApplication(
                                title = "SUMMER10",
                                type = "DISCOUNT_CODE",
                                value = AnglerPricingPercentageValue(percentage = 10),
                            ),
                        ),
                    ),
                    id = "li-1",
                    quantity = 2,
                    title = "Linen Shirt",
                    variant = AnglerProductVariant(
                        id = "41234567890",
                        price = AnglerMoney(amount = 29.5, currencyCode = "USD"),
                        product = AnglerProduct(id = "7012345678", title = "Linen Shirt"),
                        sku = "LS-BLU-M",
                        title = "Blue / M",
                    ),
                ),
                AnglerCheckoutLineItem(
                    id = "li-2",
                    quantity = 1,
                    sellingPlanAllocation = AnglerSellingPlanAllocation(
                        sellingPlan = AnglerSellingPlan(
                            id = "690012",
                            name = "Delivered every 2 weeks",
                        ),
                    ),
                    title = "Coffee Beans",
                    variant = AnglerProductVariant(
                        id = "41234567999",
                        price = AnglerMoney(amount = 20, currencyCode = "USD"),
                    ),
                ),
            ),
            order = AnglerOrder(id = "5123456789012"),
            phone = "+15555550123",
            shippingAddress = AnglerMailingAddress(
                address1 = "1 Main St",
                city = "Austin",
                country = "United States",
                countryCode = "US",
                firstName = "Jane",
                lastName = "Doe",
                province = "Texas",
                provinceCode = "TX",
                zip = "78701",
            ),
            shippingLine = AnglerShippingRate(price = AnglerMoney(amount = 5, currencyCode = "USD")),
            subtotalPrice = AnglerMoney(amount = 73.1, currencyCode = "USD"),
            token = "chk-9f2c41",
            totalPrice = AnglerMoney(amount = 84.13, currencyCode = "USD"),
            totalTax = AnglerMoney(amount = 6.03, currencyCode = "USD"),
        ),
    ),
    eventId = "5123456789012",
)
```

**React Native (TypeScript)**

```ts
Angler.track(
  AnglerEvent.checkoutCompleted,
  {
    data: {
      checkout: {
        attributes: [{ key: 'gift_message', value: 'Happy birthday!' }],
        currencyCode: 'USD',
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
        email: 'jane@example.com',
        lineItems: [
          {
            discountAllocations: [
              {
                amount: { amount: 5.9, currencyCode: 'USD' },
                discountApplication: {
                  title: 'SUMMER10',
                  type: 'DISCOUNT_CODE',
                  value: { percentage: 10 },
                },
              },
            ],
            id: 'li-1',
            quantity: 2,
            title: 'Linen Shirt',
            variant: {
              id: '41234567890',
              price: { amount: 29.5, currencyCode: 'USD' },
              product: { id: '7012345678', title: 'Linen Shirt' },
              sku: 'LS-BLU-M',
              title: 'Blue / M',
            },
          },
          {
            id: 'li-2',
            quantity: 1,
            sellingPlanAllocation: {
              sellingPlan: { id: '690012', name: 'Delivered every 2 weeks' },
            },
            title: 'Coffee Beans',
            variant: { id: '41234567999', price: { amount: 20, currencyCode: 'USD' } },
          },
        ],
        order: { id: '5123456789012' },
        phone: '+15555550123',
        shippingAddress: {
          address1: '1 Main St',
          city: 'Austin',
          country: 'United States',
          countryCode: 'US',
          firstName: 'Jane',
          lastName: 'Doe',
          province: 'Texas',
          provinceCode: 'TX',
          zip: '78701',
        },
        shippingLine: { price: { amount: 5, currencyCode: 'USD' } },
        subtotalPrice: { amount: 73.1, currencyCode: 'USD' },
        token: 'chk-9f2c41',
        totalPrice: { amount: 84.13, currencyCode: 'USD' },
        totalTax: { amount: 6.03, currencyCode: 'USD' },
      },
    },
    eventId: '5123456789012',
  },
);
```

**Flutter (Dart)**

```dart
await Angler.track(
  AnglerEvent.checkoutCompleted,
  data: const AnglerData(
    checkout: AnglerCheckout(
      attributes: [AnglerAttribute(key: 'gift_message', value: 'Happy birthday!')],
      currencyCode: 'USD',
      discountApplications: [
        AnglerDiscountApplication(
          allocationMethod: 'ACROSS',
          targetSelection: 'ALL',
          targetType: 'LINE_ITEM',
          title: 'SUMMER10',
          type: 'DISCOUNT_CODE',
          value: AnglerPricingPercentageValue(percentage: 10),
        ),
      ],
      email: 'jane@example.com',
      lineItems: [
        AnglerCheckoutLineItem(
          discountAllocations: [
            AnglerDiscountAllocation(
              amount: AnglerMoney(amount: 5.9, currencyCode: 'USD'),
              discountApplication: AnglerDiscountApplication(
                title: 'SUMMER10',
                type: 'DISCOUNT_CODE',
                value: AnglerPricingPercentageValue(percentage: 10),
              ),
            ),
          ],
          id: 'li-1',
          quantity: 2,
          title: 'Linen Shirt',
          variant: AnglerProductVariant(
            id: '41234567890',
            price: AnglerMoney(amount: 29.5, currencyCode: 'USD'),
            product: AnglerProduct(id: '7012345678', title: 'Linen Shirt'),
            sku: 'LS-BLU-M',
            title: 'Blue / M',
          ),
        ),
        AnglerCheckoutLineItem(
          id: 'li-2',
          quantity: 1,
          sellingPlanAllocation: AnglerSellingPlanAllocation(
            sellingPlan: AnglerSellingPlan(id: '690012', name: 'Delivered every 2 weeks'),
          ),
          title: 'Coffee Beans',
          variant: AnglerProductVariant(
            id: '41234567999',
            price: AnglerMoney(amount: 20, currencyCode: 'USD'),
          ),
        ),
      ],
      order: AnglerOrder(id: '5123456789012'),
      phone: '+15555550123',
      shippingAddress: AnglerMailingAddress(
        address1: '1 Main St',
        city: 'Austin',
        country: 'United States',
        countryCode: 'US',
        firstName: 'Jane',
        lastName: 'Doe',
        province: 'Texas',
        provinceCode: 'TX',
        zip: '78701',
      ),
      shippingLine: AnglerShippingRate(price: AnglerMoney(amount: 5, currencyCode: 'USD')),
      subtotalPrice: AnglerMoney(amount: 73.1, currencyCode: 'USD'),
      token: 'chk-9f2c41',
      totalPrice: AnglerMoney(amount: 84.13, currencyCode: 'USD'),
      totalTax: AnglerMoney(amount: 6.03, currencyCode: 'USD'),
    ),
  ),
  eventId: '5123456789012',
);
```

**JSON sent**

```json
{
  "checkout": {
    "token": "chk-9f2c41",
    "currencyCode": "USD",
    "email": "jane@example.com",
    "phone": "+15555550123",
    "order": {
      "id": "5123456789012"
    },
    "lineItems": [
      {
        "id": "li-1",
        "quantity": 2,
        "title": "Linen Shirt",
        "variant": {
          "id": "41234567890",
          "title": "Blue / M",
          "sku": "LS-BLU-M",
          "price": {
            "amount": 29.5,
            "currencyCode": "USD"
          },
          "product": {
            "id": "7012345678",
            "title": "Linen Shirt"
          }
        },
        "discountAllocations": [
          {
            "amount": {
              "amount": 5.9,
              "currencyCode": "USD"
            },
            "discountApplication": {
              "title": "SUMMER10",
              "type": "DISCOUNT_CODE",
              "value": {
                "percentage": 10
              }
            }
          }
        ]
      },
      {
        "id": "li-2",
        "quantity": 1,
        "title": "Coffee Beans",
        "variant": {
          "id": "41234567999",
          "price": {
            "amount": 20,
            "currencyCode": "USD"
          }
        },
        "sellingPlanAllocation": {
          "sellingPlan": {
            "id": "690012",
            "name": "Delivered every 2 weeks"
          }
        }
      }
    ],
    "discountApplications": [
      {
        "allocationMethod": "ACROSS",
        "targetSelection": "ALL",
        "targetType": "LINE_ITEM",
        "title": "SUMMER10",
        "type": "DISCOUNT_CODE",
        "value": {
          "percentage": 10
        }
      }
    ],
    "subtotalPrice": {
      "amount": 73.1,
      "currencyCode": "USD"
    },
    "shippingLine": {
      "price": {
        "amount": 5,
        "currencyCode": "USD"
      }
    },
    "totalTax": {
      "amount": 6.03,
      "currencyCode": "USD"
    },
    "totalPrice": {
      "amount": 84.13,
      "currencyCode": "USD"
    },
    "shippingAddress": {
      "firstName": "Jane",
      "lastName": "Doe",
      "address1": "1 Main St",
      "city": "Austin",
      "province": "Texas",
      "provinceCode": "TX",
      "country": "United States",
      "countryCode": "US",
      "zip": "78701"
    },
    "attributes": [
      {
        "key": "gift_message",
        "value": "Happy birthday!"
      }
    ]
  }
}
```

## Used in

- [AnglerData](../data/README.md): `checkout`

<sub>Generated by `scripts/generate-docs.mjs`; edit `scripts/docs-content.mjs` or the schema, not this page.</sub>
