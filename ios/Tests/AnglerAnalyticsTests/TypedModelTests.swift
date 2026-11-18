import XCTest
@testable import AnglerAnalytics

/// The shared typed-data fixture, built with the generated Swift models.
enum TypedDataCases {
    static func build(_ name: String) -> AnglerData? {
        switch name {
        case "cart_line_added":
            return AnglerData(cartLine: AnglerCartLine(
                cost: AnglerCartLineCost(totalAmount: AnglerMoney(amount: 58, currencyCode: "USD")),
                merchandise: AnglerProductVariant(
                    id: "variant-1",
                    image: AnglerImage(src: "https://cdn.example.com/v1.jpg"),
                    price: AnglerMoney(amount: 29, currencyCode: "USD"),
                    product: AnglerProduct(id: "product-1", title: "Linen Shirt", vendor: "Example", type: "Shirts",
                                           url: "https://shop.example.com/products/linen-shirt"),
                    sku: "SKU-1",
                    title: "Blue / M"
                ),
                quantity: 2
            ))
        case "checkout_with_discounts":
            let summer = AnglerDiscountApplication(title: "SUMMER", type: "DISCOUNT_CODE",
                                                   value: .pricingPercentageValue(AnglerPricingPercentageValue(percentage: 10)))
            return AnglerData(checkout: AnglerCheckout(
                currencyCode: "USD",
                discountApplications: [
                    summer,
                    AnglerDiscountApplication(title: "Free gift", type: "AUTOMATIC",
                                              value: .money(AnglerMoney(amount: 5, currencyCode: "USD"))),
                ],
                lineItems: [AnglerCheckoutLineItem(
                    discountAllocations: [AnglerDiscountAllocation(
                        amount: AnglerMoney(amount: 2.9, currencyCode: "USD"),
                        discountApplication: AnglerDiscountApplication(title: "SUMMER", value: .pricingPercentageValue(.init(percentage: 10)))
                    )],
                    id: "li-1",
                    quantity: 1,
                    title: "Linen Shirt",
                    variant: AnglerProductVariant(id: "variant-1")
                )],
                shippingAddress: AnglerMailingAddress(city: "Austin", countryCode: "US", zip: "78701"),
                token: "chk-1",
                totalPrice: AnglerMoney(amount: 49.5, currencyCode: "USD")
            ))
        case "search_and_custom_data":
            return AnglerData(
                searchResult: AnglerSearchResult(query: "linen", productVariants: [AnglerProductVariant(id: "variant-1"),
                                                                                 AnglerProductVariant(id: "variant-2")]),
                customData: [AnglerCustomValue(name: "source", value: "home_banner")]
            )
        case "form_submitted":
            return AnglerData(form: AnglerFormElement(id: "newsletter", action: "/subscribe",
                                                      elements: [AnglerInputElement(name: "email", tagName: "INPUT", type: "email")]))
        default:
            return nil
        }
    }
}

final class TypedModelTests: XCTestCase {
    func testTypedDataFixtures() throws {
        let cases = try Fixtures.load("typed-data")
        XCTAssertEqual(cases.count, 4)
        for c in cases {
            let data = try XCTUnwrap(TypedDataCases.build(c.name), c.name)
            XCTAssertEqual(JSONValue.object(data.jsonObject), c.expected, c.name)
        }
    }

    func testEventNames() {
        XCTAssertEqual(AnglerEvent.productAddedToCart.name, "product_added_to_cart")
        XCTAssertEqual(AnglerEvent.custom("level_up").name, "level_up")
        XCTAssertTrue(StandardEvent.names.isSuperset(of: [AnglerEvent.checkoutCompleted.name, AnglerEvent.appLaunched.name]))
    }
}
