package ai.getangler.analytics

import ai.getangler.analytics.payload.JsonValue
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** The shared typed-data fixture, built with the generated Kotlin models. */
internal object TypedDataCases {
    fun build(name: String): AnglerData? = when (name) {
        "cart_line_added" -> AnglerData(
            cartLine = AnglerCartLine(
                quantity = 2,
                cost = AnglerCartLineCost(totalAmount = AnglerMoney(amount = 58, currencyCode = "USD")),
                merchandise = AnglerProductVariant(
                    id = "variant-1",
                    sku = "SKU-1",
                    title = "Blue / M",
                    price = AnglerMoney(amount = 29, currencyCode = "USD"),
                    image = AnglerImage(src = "https://cdn.example.com/v1.jpg"),
                    product = AnglerProduct(
                        id = "product-1", title = "Linen Shirt", vendor = "Example", type = "Shirts",
                        url = "https://shop.example.com/products/linen-shirt",
                    ),
                ),
            ),
        )
        "checkout_with_discounts" -> AnglerData(
            checkout = AnglerCheckout(
                token = "chk-1",
                currencyCode = "USD",
                totalPrice = AnglerMoney(amount = 49.5, currencyCode = "USD"),
                discountApplications = listOf(
                    AnglerDiscountApplication(title = "SUMMER", type = "DISCOUNT_CODE", value = AnglerPricingPercentageValue(percentage = 10)),
                    AnglerDiscountApplication(title = "Free gift", type = "AUTOMATIC", value = AnglerMoney(amount = 5, currencyCode = "USD")),
                ),
                lineItems = listOf(
                    AnglerCheckoutLineItem(
                        id = "li-1",
                        quantity = 1,
                        title = "Linen Shirt",
                        variant = AnglerProductVariant(id = "variant-1"),
                        discountAllocations = listOf(
                            AnglerDiscountAllocation(
                                amount = AnglerMoney(amount = 2.9, currencyCode = "USD"),
                                discountApplication = AnglerDiscountApplication(title = "SUMMER", value = AnglerPricingPercentageValue(percentage = 10)),
                            ),
                        ),
                    ),
                ),
                shippingAddress = AnglerMailingAddress(city = "Austin", countryCode = "US", zip = "78701"),
            ),
        )
        "search_and_custom_data" -> AnglerData(
            searchResult = AnglerSearchResult(query = "linen", productVariants = listOf(AnglerProductVariant(id = "variant-1"), AnglerProductVariant(id = "variant-2"))),
            customData = listOf(AnglerCustomValue(name = "source", value = "home_banner")),
        )
        "form_submitted" -> AnglerData(
            form = AnglerFormElement(id = "newsletter", action = "/subscribe", elements = listOf(AnglerInputElement(name = "email", type = "email", tagName = "INPUT"))),
        )
        else -> null
    }
}

class TypedModelTest {
    @Test fun typedDataFixtures() {
        val cases = Fixtures.load("typed-data")
        assertEquals(4, cases.size)
        for (c in cases) {
            val data = TypedDataCases.build(c.name)
            assertNotNull(c.name, data)
            assertEquals(c.name, c.expected, data!!.toJsonValue())
        }
    }

    @Test fun eventNames() {
        assertEquals("product_added_to_cart", AnglerEvent.ProductAddedToCart.name)
        assertEquals("level_up", AnglerEvent.Custom("level_up").name)
        assertEquals(AnglerEvent.Custom("x"), AnglerEvent.Custom("x"))
        assertTrue(ai.getangler.analytics.payload.StandardEvent.isStandard(AnglerEvent.CheckoutCompleted.name))
    }
}
