# AnglerProductVariant

A product variant (the thing a shopper buys: a size or color of a product). Use the same ID as your product catalog (on Shopify, the variant ID) so ad platforms can match it.

Sent as `data.productVariant`. Usually sent with `product_viewed`.

[All data objects](../README.md)

## Fields

Every field is optional unless it says **Required**. Leave out what you don't have.

| Field | Type | Description |
|---|---|---|
| `id` | string | A globally unique identifier. Use the same ID as your product catalog. |
| `image` | [AnglerImage](../image/README.md) | Image associated with the product variant. This field falls back to the product image if no image is available. |
| `inventoryItem` | [AnglerInventoryItem](../inventory-item/README.md) | The inventory item associated with the product variant, including its per-item cost (COGS). |
| `price` | [AnglerMoney](../money/README.md) | A monetary value with currency. |
| `product` | [AnglerProduct](../product/README.md) | The product object that the product variant belongs to. |
| `sku` | string | The SKU (stock keeping unit) associated with the variant. |
| `title` | string | The product variant’s title. |
| `untranslatedTitle` | string | The product variant’s untranslated title. |

## Example

**Swift**

```swift
Angler.track(
    .productViewed,
    data: AnglerData(
        productVariant: AnglerProductVariant(
            id: "41234567890",
            image: AnglerImage(src: "https://cdn.example.com/linen-shirt-blue.jpg"),
            inventoryItem: AnglerInventoryItem(
                id: "43210987654",
                cost: AnglerMoney(amount: 12, currencyCode: "USD")
            ),
            price: AnglerMoney(amount: 29.5, currencyCode: "USD"),
            product: AnglerProduct(
                id: "7012345678",
                title: "Linen Shirt",
                vendor: "Example Co",
                type: "Shirts",
                url: "/products/linen-shirt"
            ),
            sku: "LS-BLU-M",
            title: "Blue / M"
        )
    )
)
```

**Kotlin**

```kotlin
Angler.track(
    AnglerEvent.ProductViewed,
    AnglerData(
        productVariant = AnglerProductVariant(
            id = "41234567890",
            image = AnglerImage(src = "https://cdn.example.com/linen-shirt-blue.jpg"),
            inventoryItem = AnglerInventoryItem(
                id = "43210987654",
                cost = AnglerMoney(amount = 12, currencyCode = "USD"),
            ),
            price = AnglerMoney(amount = 29.5, currencyCode = "USD"),
            product = AnglerProduct(
                id = "7012345678",
                title = "Linen Shirt",
                vendor = "Example Co",
                type = "Shirts",
                url = "/products/linen-shirt",
            ),
            sku = "LS-BLU-M",
            title = "Blue / M",
        ),
    ),
)
```

**React Native (TypeScript)**

```ts
Angler.track(
  AnglerEvent.productViewed,
  {
    data: {
      productVariant: {
        id: '41234567890',
        image: { src: 'https://cdn.example.com/linen-shirt-blue.jpg' },
        inventoryItem: { id: '43210987654', cost: { amount: 12, currencyCode: 'USD' } },
        price: { amount: 29.5, currencyCode: 'USD' },
        product: {
          id: '7012345678',
          title: 'Linen Shirt',
          vendor: 'Example Co',
          type: 'Shirts',
          url: '/products/linen-shirt',
        },
        sku: 'LS-BLU-M',
        title: 'Blue / M',
      },
    },
  },
);
```

**Flutter (Dart)**

```dart
await Angler.track(
  AnglerEvent.productViewed,
  data: const AnglerData(
    productVariant: AnglerProductVariant(
      id: '41234567890',
      image: AnglerImage(src: 'https://cdn.example.com/linen-shirt-blue.jpg'),
      inventoryItem: AnglerInventoryItem(
        id: '43210987654',
        cost: AnglerMoney(amount: 12, currencyCode: 'USD'),
      ),
      price: AnglerMoney(amount: 29.5, currencyCode: 'USD'),
      product: AnglerProduct(
        id: '7012345678',
        title: 'Linen Shirt',
        vendor: 'Example Co',
        type: 'Shirts',
        url: '/products/linen-shirt',
      ),
      sku: 'LS-BLU-M',
      title: 'Blue / M',
    ),
  ),
);
```

**JSON sent**

```json
{
  "productVariant": {
    "id": "41234567890",
    "title": "Blue / M",
    "sku": "LS-BLU-M",
    "price": {
      "amount": 29.5,
      "currencyCode": "USD"
    },
    "image": {
      "src": "https://cdn.example.com/linen-shirt-blue.jpg"
    },
    "product": {
      "id": "7012345678",
      "title": "Linen Shirt",
      "vendor": "Example Co",
      "type": "Shirts",
      "url": "/products/linen-shirt"
    },
    "inventoryItem": {
      "id": "43210987654",
      "cost": {
        "amount": 12,
        "currencyCode": "USD"
      }
    }
  }
}
```

## Used in

- [AnglerData](../data/README.md): `productVariant`
- [AnglerCartLine](../cart-line/README.md): `merchandise`
- [AnglerCheckoutLineItem](../checkout-line-item/README.md): `variant`
- [AnglerCollection](../collection/README.md): `productVariants`
- [AnglerSearchResult](../search-result/README.md): `productVariants`

<sub>Generated by `scripts/generate-docs.mjs`; edit `scripts/docs-content.mjs` or the schema, not this page.</sub>
