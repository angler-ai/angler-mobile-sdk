# Events and data objects

Every event can carry a `data` object, [AnglerData](data/README.md), with the commerce objects the event is about. Each SDK has typed classes for all of them (`AnglerData`, `AnglerCartLine`, `AnglerMoney`, …), generated from the events API's schema, so the field names below are the same in Swift, Kotlin, TypeScript, Dart and the JSON that's sent.

Each page lists the fields and shows a full example in every language. To install and configure the SDK, see the [main README](../README.md).

## Events

| Event | Data to attach |
|---|---|
| `app_installed` | — |
| `app_launched` | — |
| `page_viewed` | — |
| `product_viewed` | `productVariant` ([AnglerProductVariant](product-variant/README.md)) |
| `collection_viewed` | `collection` ([AnglerCollection](collection/README.md)) |
| `search_submitted` | `searchResult` ([AnglerSearchResult](search-result/README.md)) |
| `product_added_to_cart` | `cartLine` ([AnglerCartLine](cart-line/README.md)) |
| `product_removed_from_cart` | `cartLine` ([AnglerCartLine](cart-line/README.md)) |
| `cart_viewed` | `cart` ([AnglerCart](cart/README.md)) |
| `checkout_started` | `checkout` ([AnglerCheckout](checkout/README.md)) |
| `checkout_contact_info_submitted` | `checkout` ([AnglerCheckout](checkout/README.md)) |
| `checkout_address_info_submitted` | `checkout` ([AnglerCheckout](checkout/README.md)) |
| `checkout_shipping_info_submitted` | `checkout` ([AnglerCheckout](checkout/README.md)) |
| `payment_info_submitted` | `checkout` ([AnglerCheckout](checkout/README.md)) |
| `checkout_completed` | `checkout` ([AnglerCheckout](checkout/README.md)) |
| `form_submitted` | `form` ([AnglerFormElement](form-element/README.md)) |
| `registration_completed` | `customer` ([AnglerCustomer](customer/README.md)) |
| `logged_in` | `customer` ([AnglerCustomer](customer/README.md)) |
| any other name (a custom event) | `customData` ([AnglerCustomValue](custom-value/README.md)) |

`app_installed` and `app_launched` are sent automatically.

## Data objects

The fields of [AnglerData](data/README.md):

| Field | Type | |
|---|---|---|
| `cart` | [AnglerCart](cart/README.md) | The cart, for `cart_viewed`. |
| `cartLine` | [AnglerCartLine](cart-line/README.md) | The line added or removed, for `product_added_to_cart` and `product_removed_from_cart`. |
| `checkout` | [AnglerCheckout](checkout/README.md) | The checkout, for the checkout events and `payment_info_submitted`. |
| `collection` | [AnglerCollection](collection/README.md) | The collection viewed, for `collection_viewed`. |
| `productVariant` | [AnglerProductVariant](product-variant/README.md) | The variant viewed, for `product_viewed`. |
| `searchResult` | [AnglerSearchResult](search-result/README.md) | The search, for `search_submitted`. |
| `customer` | [AnglerCustomer](customer/README.md) | The customer, for `registration_completed` and `logged_in`. |
| `form` | [AnglerFormElement](form-element/README.md) | The form, for `form_submitted`. |
| `contacts` | list of [AnglerCustomer](customer/README.md) | Other people the event refers to, in the same shape as `customer`. |
| `customData` | list of [AnglerCustomValue](custom-value/README.md) | Your own name/value pairs; a custom event's details go here. `track`'s `properties` argument adds to it. |

## Nested types

- [AnglerAttribute](attribute/README.md): A custom key/value pair on the checkout, such as a gift message.
- [AnglerCartCost](cart-cost/README.md): The estimated costs that the customer will pay at checkout.
- [AnglerCartLineCost](cart-line-cost/README.md): The cost of the merchandise line that the buyer will pay at checkout.
- [AnglerCheckoutLineItem](checkout-line-item/README.md): One line of a checkout: a variant, its quantity and any discounts on it.
- [AnglerDiscountAllocation](discount-allocation/README.md): An amount discounting the line that has been allocated by a discount.
- [AnglerDiscountApplication](discount-application/README.md): Discount applications capture the intentions of a discount source at the time of application.
- [AnglerDiscountApplicationValue](discount-application-value/README.md): The value of a discount: a percentage (`AnglerPricingPercentageValue`) or a fixed amount (`AnglerMoney`).
- [AnglerImage](image/README.md): An image of the product variant (or of the product, if the variant has none).
- [AnglerInputElement](input-element/README.md): One input of a submitted form.
- [AnglerInventoryItem](inventory-item/README.md): The inventory item associated with the product variant, including its per-item cost (COGS).
- [AnglerMailingAddress](mailing-address/README.md): A shipping or billing address.
- [AnglerMoney](money/README.md): An amount of money and its currency.
- [AnglerOrder](order/README.md): The order a completed checkout created.
- [AnglerPricingPercentageValue](pricing-percentage-value/README.md): A discount given as a percentage.
- [AnglerProduct](product/README.md): The product object that the product variant belongs to.
- [AnglerSellingPlan](selling-plan/README.md): A representation of how products and variants can be sold and purchased. For example, an individual selling plan could be '6 weeks of prepaid granola, delivered weekly'.
- [AnglerSellingPlanAllocation](selling-plan-allocation/README.md): The selling plan associated with the line item and the effect that each selling plan has on variants when they're purchased.
- [AnglerShippingRate](shipping-rate/README.md): The shipping rate chosen at checkout.

## Good to know

- **Leave out what you don't have.** Every field is optional unless its page says **Required**, and fields you leave out aren't sent.
- **Money** is a decimal amount in the currency's main unit (`29.99`, not `2999`) with an ISO 4217 currency code.
- **IDs** are strings. Use the same product and variant IDs as your product catalog, so ad platforms can match them.
- **Purchases:** on `checkout_completed`, set `checkout.order.id` and `checkout.totalPrice`, and pass the order ID as `eventId`, so the purchase isn't counted twice.
- **Customer details** (email, phone, name) help match app activity to ad clicks. They're sent over HTTPS; the `hashed*` fields take SHA-256 hashes of lowercased values if you only have those.
- **Untyped form:** every SDK also takes `data` as a plain map or JSON object with these same keys (`trackJson` in Flutter).

<sub>Generated by `scripts/generate-docs.mjs` from the schema snapshot in `spec/schema` and `scripts/docs-content.mjs`. Edit those, not these pages.</sub>
