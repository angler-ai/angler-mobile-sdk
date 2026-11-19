# AnglerCart

The shopper's cart, sent with `cart_viewed`.

Sent as `data.cart`. Usually sent with `cart_viewed`.

[All data objects](../README.md)

## Fields

Every field is optional unless it says **Required**. Leave out what you don't have.

| Field | Type | Description |
|---|---|---|
| `cost` | [AnglerCartCost](../cart-cost/README.md) | The estimated costs that the customer will pay at checkout. |
| `id` | string | A globally unique identifier. |
| `lines` | list of [AnglerCartLine](../cart-line/README.md) | The lines in the cart. |
| `totalQuantity` | number | The total number of items in the cart. |

## Example

**Swift**

```swift
Angler.track(
    .cartViewed,
    data: AnglerData(
        cart: AnglerCart(
            cost: AnglerCartCost(totalAmount: AnglerMoney(amount: 79, currencyCode: "USD")),
            id: "c1-7d3e9a",
            lines: [
                AnglerCartLine(
                    cost: AnglerCartLineCost(
                        totalAmount: AnglerMoney(amount: 59, currencyCode: "USD")
                    ),
                    merchandise: AnglerProductVariant(
                        id: "41234567890",
                        price: AnglerMoney(amount: 29.5, currencyCode: "USD"),
                        title: "Blue / M"
                    ),
                    quantity: 2
                ),
                AnglerCartLine(
                    cost: AnglerCartLineCost(
                        totalAmount: AnglerMoney(amount: 20, currencyCode: "USD")
                    ),
                    merchandise: AnglerProductVariant(
                        id: "41234567999",
                        price: AnglerMoney(amount: 20, currencyCode: "USD"),
                        title: "Default"
                    ),
                    quantity: 1
                )
            ],
            totalQuantity: 3
        )
    )
)
```

**Kotlin**

```kotlin
Angler.track(
    AnglerEvent.CartViewed,
    AnglerData(
        cart = AnglerCart(
            cost = AnglerCartCost(totalAmount = AnglerMoney(amount = 79, currencyCode = "USD")),
            id = "c1-7d3e9a",
            lines = listOf(
                AnglerCartLine(
                    cost = AnglerCartLineCost(
                        totalAmount = AnglerMoney(amount = 59, currencyCode = "USD"),
                    ),
                    merchandise = AnglerProductVariant(
                        id = "41234567890",
                        price = AnglerMoney(amount = 29.5, currencyCode = "USD"),
                        title = "Blue / M",
                    ),
                    quantity = 2,
                ),
                AnglerCartLine(
                    cost = AnglerCartLineCost(
                        totalAmount = AnglerMoney(amount = 20, currencyCode = "USD"),
                    ),
                    merchandise = AnglerProductVariant(
                        id = "41234567999",
                        price = AnglerMoney(amount = 20, currencyCode = "USD"),
                        title = "Default",
                    ),
                    quantity = 1,
                ),
            ),
            totalQuantity = 3,
        ),
    ),
)
```

**React Native (TypeScript)**

```ts
Angler.track(
  AnglerEvent.cartViewed,
  {
    data: {
      cart: {
        cost: { totalAmount: { amount: 79, currencyCode: 'USD' } },
        id: 'c1-7d3e9a',
        lines: [
          {
            cost: { totalAmount: { amount: 59, currencyCode: 'USD' } },
            merchandise: {
              id: '41234567890',
              price: { amount: 29.5, currencyCode: 'USD' },
              title: 'Blue / M',
            },
            quantity: 2,
          },
          {
            cost: { totalAmount: { amount: 20, currencyCode: 'USD' } },
            merchandise: {
              id: '41234567999',
              price: { amount: 20, currencyCode: 'USD' },
              title: 'Default',
            },
            quantity: 1,
          },
        ],
        totalQuantity: 3,
      },
    },
  },
);
```

**Flutter (Dart)**

```dart
await Angler.track(
  AnglerEvent.cartViewed,
  data: const AnglerData(
    cart: AnglerCart(
      cost: AnglerCartCost(totalAmount: AnglerMoney(amount: 79, currencyCode: 'USD')),
      id: 'c1-7d3e9a',
      lines: [
        AnglerCartLine(
          cost: AnglerCartLineCost(totalAmount: AnglerMoney(amount: 59, currencyCode: 'USD')),
          merchandise: AnglerProductVariant(
            id: '41234567890',
            price: AnglerMoney(amount: 29.5, currencyCode: 'USD'),
            title: 'Blue / M',
          ),
          quantity: 2,
        ),
        AnglerCartLine(
          cost: AnglerCartLineCost(totalAmount: AnglerMoney(amount: 20, currencyCode: 'USD')),
          merchandise: AnglerProductVariant(
            id: '41234567999',
            price: AnglerMoney(amount: 20, currencyCode: 'USD'),
            title: 'Default',
          ),
          quantity: 1,
        ),
      ],
      totalQuantity: 3,
    ),
  ),
);
```

**JSON sent**

```json
{
  "cart": {
    "id": "c1-7d3e9a",
    "totalQuantity": 3,
    "cost": {
      "totalAmount": {
        "amount": 79,
        "currencyCode": "USD"
      }
    },
    "lines": [
      {
        "quantity": 2,
        "cost": {
          "totalAmount": {
            "amount": 59,
            "currencyCode": "USD"
          }
        },
        "merchandise": {
          "id": "41234567890",
          "title": "Blue / M",
          "price": {
            "amount": 29.5,
            "currencyCode": "USD"
          }
        }
      },
      {
        "quantity": 1,
        "cost": {
          "totalAmount": {
            "amount": 20,
            "currencyCode": "USD"
          }
        },
        "merchandise": {
          "id": "41234567999",
          "title": "Default",
          "price": {
            "amount": 20,
            "currencyCode": "USD"
          }
        }
      }
    ]
  }
}
```

## Used in

- [AnglerData](../data/README.md): `cart`

<sub>Generated by `scripts/generate-docs.mjs`; edit `scripts/docs-content.mjs` or the schema, not this page.</sub>
