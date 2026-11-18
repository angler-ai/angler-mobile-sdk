import Foundation

struct TrackCall {
    var name: String
    var data: [String: JSONValue]?
    var properties: [String: String]?
    var eventId: String?
}

struct IdentitySnapshot {
    var aid: String
    var customerId: String?
    /// `idfa` on iOS, `gaid` on Android.
    var adIdName: String
    var adId: String?
    var custom: [String: String]
}

struct DeviceProperty: Equatable {
    var name: String
    var value: String
}

struct DeviceSnapshot {
    var properties: [DeviceProperty]
    var userAgent: String
}

/// Turns a track call plus snapshots into one event (design §5). Pure.
enum PayloadBuilder {
    static let allowedDataKeys: Set<String> = [
        "cart", "cartLine", "checkout", "collection", "productVariant",
        "searchResult", "customer", "form", "contacts", "customData",
    ]

    /// data-api's `device_properties[].name` enum. `app_id` is the store app ID (App Store ID on
    /// iOS, package name on Android), the same value the AppsFlyer import sends.
    static let allowedDeviceProperties: Set<String> = [
        "app_id", "app_package", "app_version_short", "app_version_long", "os", "os_version",
        "device_model_name", "device_timezone", "locale", "timezone_abbreviation", "carrier",
        "screen_width", "screen_height", "screen_density", "cpu_cores", "ext_storage_in_gb",
        "free_ext_storage_in_gb", "advertiser_tracking_enabled", "application_tracking_enabled",
    ]

    static func buildEvent(
        call: TrackCall,
        generatedEventId: String,
        timestamp: String,
        clientIdOverride: String?,
        identity: IdentitySnapshot,
        attribution: AttributionSnapshot,
        device: DeviceSnapshot,
        referrer: String?
    ) -> JSONValue {
        var event: [String: JSONValue] = [:]
        event["event_id"] = .string(nonEmpty(call.eventId) ?? generatedEventId)
        if StandardEvent.isStandard(call.name) {
            event["event_name"] = .string(call.name)
        } else {
            event["event_name"] = .string("custom_event")
            event["custom_event_name"] = .string(call.name)
        }
        event["timestamp"] = .string(timestamp)
        event["client_id"] = .string(nonEmpty(clientIdOverride) ?? identity.aid)
        event["user_agent"] = .string(device.userAgent)
        if let url = nonEmpty(attribution.url) { event["url"] = .string(url) }
        if let referrer = nonEmpty(referrer) { event["referrer"] = .string(referrer) }
        if let fbc = nonEmpty(attribution.fbc) { event["fbc"] = .string(fbc) }
        event["identifiers"] = .array(identifiers(identity: identity, clickIds: attribution.clickIds))
        let props = device.properties.filter { allowedDeviceProperties.contains($0.name) && !$0.value.isEmpty }
        if !props.isEmpty {
            event["device_properties"] = .array(props.map { .object(["name": .string($0.name), "value": .string($0.value)]) })
        }
        event["data"] = .object(data(call.data, properties: call.properties))
        return .object(event)
    }

    static func buildBody(src: String, events: [JSONValue]) -> JSONValue {
        .object(["src": .string(src), "data": .array(events)])
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    /// UTC ISO-8601 with milliseconds, e.g. `2026-11-17T18:04:05.123Z`.
    static func timestamp(_ date: Date) -> String {
        let ms = date.epochMillis
        let seconds = Date(timeIntervalSince1970: TimeInterval(ms.floorDiv(1000)))
        let base = isoFormatter.string(from: seconds) // "…T18:04:05Z"
        return String(base.dropLast()) + String(format: ".%03lldZ", ms.floorMod(1000))
    }

    // MARK: - Private

    private static func identifiers(identity: IdentitySnapshot, clickIds: [String: String]) -> [JSONValue] {
        var pairs: [(String, String?)] = [("aid", identity.aid), ("customer_id", identity.customerId), (identity.adIdName, identity.adId)]
        pairs += clickIds.sorted { $0.key < $1.key }.map { ($0.key, $0.value) }
        pairs += identity.custom
            .filter { !IdentityStore.reservedNames.contains($0.key) }
            .sorted { $0.key < $1.key }
            .map { ($0.key, $0.value) }
        return pairs.compactMap { name, value in
            guard let value = nonEmpty(value) else { return nil }
            return .object(["name": .string(name), "value": .string(value)])
        }
    }

    private static func data(_ data: [String: JSONValue]?, properties: [String: String]?) -> [String: JSONValue] {
        var out: [String: JSONValue] = [:]
        for (key, value) in data ?? [:] {
            if allowedDataKeys.contains(key) {
                out[key] = value
            } else {
                Log.debug("dropping data key '\(key)': not accepted by data-api")
            }
        }
        var custom: [JSONValue] = []
        if let existing = out["customData"]?.arrayValue {
            custom = existing.filter { item in
                guard let o = item.objectValue, o.count == 2,
                      o["name"]?.stringValue != nil, o["value"]?.stringValue != nil else {
                    Log.debug("dropping customData entry: must be {name: string, value: string}")
                    return false
                }
                return true
            }
        }
        for (name, value) in (properties ?? [:]).sorted(by: { $0.key < $1.key }) {
            custom.append(.object(["name": .string(name), "value": .string(value)]))
        }
        out["customData"] = custom.isEmpty ? nil : .array(custom)
        return out
    }

    private static func nonEmpty(_ s: String?) -> String? {
        guard let s, !s.isEmpty else { return nil }
        return s
    }
}

private extension Int64 {
    func floorDiv(_ d: Int64) -> Int64 { (self >= 0 ? self : self - d + 1) / d }
    func floorMod(_ d: Int64) -> Int64 { self - floorDiv(d) * d }
}
