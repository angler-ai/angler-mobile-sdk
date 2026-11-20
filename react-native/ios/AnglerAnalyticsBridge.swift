import Foundation

/// The React Native module's entry into the Swift core (compiled into the same pod from
/// `ios/vendor/AnglerAnalytics`). One method per spec method, taking the same JSON strings.
@objc(AnglerAnalyticsBridge)
public final class AnglerAnalyticsBridge: NSObject {
    @objc public static func configure(_ configJson: String) {
        guard let config = parseConfiguration(configJson) else {
            Log.warning("configure: invalid configuration JSON; ignored")
            return
        }
        Angler.configure(config)
    }

    @objc public static func track(_ name: String, dataJson: String?, propertiesJson: String?, eventId: String?) {
        let data = dataJson.flatMap { jsonObject($0) as? [String: Any] }
        let properties = propertiesJson.flatMap { jsonObject($0) as? [String: Any] }?.compactMapValues { $0 as? String }
        Angler.track(name, data: data, properties: properties, eventId: eventId)
    }

    @objc public static func handleDeepLink(_ url: String) { Angler.handleDeepLink(urlString: url) }

    @objc public static func setUserId(_ userId: String?) { Angler.setUserId(userId) }

    @objc public static func setIdentifier(_ name: String, value: String?) { Angler.setIdentifier(name, value: value) }

    @objc public static func setApplicationTrackingEnabled(_ enabled: Bool) { Angler.setApplicationTrackingEnabled(enabled) }

    @objc public static func setEnabled(_ enabled: Bool) { Angler.setEnabled(enabled) }

    @objc public static func flush() { Angler.flush() }

    @objc public static func reset() { Angler.reset() }

    @objc public static func getClientId(_ completion: @escaping (String?) -> Void) {
        Angler.getClientId(completion: completion)
    }

    /// JSON from `src/index.ts` → configuration with `wrapper = "react-native"`. Nil if invalid.
    static func parseConfiguration(_ json: String) -> AnglerConfiguration? {
        guard let o = jsonObject(json) as? [String: Any],
              let workspaceId = o["workspaceId"] as? String, !workspaceId.isEmpty,
              let token = o["token"] as? String, !token.isEmpty
        else { return nil }
        var config = AnglerConfiguration(workspaceId: workspaceId, token: token)
        if let v = o["domain"] as? String, !v.isEmpty { config.domain = v }
        if let v = o["clientId"] as? String, !v.isEmpty { config.clientId = v }
        if let v = o["appStoreId"] as? String, !v.isEmpty { config.appStoreId = v }
        if let v = o["trackLifecycleEvents"] as? Bool { config.trackLifecycleEvents = v }
        if let v = o["flushAt"] as? NSNumber { config.flushAt = v.intValue }
        if let v = o["flushIntervalSeconds"] as? NSNumber { config.flushInterval = v.doubleValue }
        if let v = o["maxQueueSize"] as? NSNumber { config.maxQueueSize = v.intValue }
        if let v = o["debugLogging"] as? Bool { config.debugLogging = v }
        config.wrapper = "react-native"
        return config
    }

    private static func jsonObject(_ s: String) -> Any? {
        guard let data = s.data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: data)
    }
}
