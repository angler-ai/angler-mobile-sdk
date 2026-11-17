/// The `event_name` values data-api accepts (`WorkspacesEventsPostBody`).
enum StandardEvent {
    static let names: Set<String> = [
        "app_installed",
        "app_launched",
        "cart_viewed",
        "checkout_address_info_submitted",
        "checkout_completed",
        "checkout_contact_info_submitted",
        "checkout_shipping_info_submitted",
        "checkout_started",
        "collection_viewed",
        "custom_event",
        "form_submitted",
        "logged_in",
        "page_viewed",
        "payment_info_submitted",
        "product_added_to_cart",
        "product_removed_from_cart",
        "product_viewed",
        "registration_completed",
        "search_submitted",
    ]

    static func isStandard(_ name: String) -> Bool { names.contains(name) }
}
