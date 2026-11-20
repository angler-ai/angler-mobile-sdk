import Flutter
import Foundation

/// Handles the `ai.getangler/analytics` channel by calling the Swift core (compiled into this
/// pod from `Classes/vendor/AnglerAnalytics`). Replies `nil` to every call but `getClientId`.
public class AnglerAnalyticsPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "ai.getangler/analytics", binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(AnglerAnalyticsPlugin(), channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [:]
        switch call.method {
        case "configure":
            if let config = Self.configuration(args) {
                Angler.configure(config)
            } else {
                Log.warning("configure: workspaceId and token are required; ignored")
            }
        case "track":
            guard let name = args["name"] as? String else { break }
            let data = (args["dataJson"] as? String).flatMap { Self.jsonObject($0) as? [String: Any] }
            let properties = (args["propertiesJson"] as? String)
                .flatMap { Self.jsonObject($0) as? [String: Any] }?
                .compactMapValues { $0 as? String }
            Angler.track(name, data: data, properties: properties, eventId: args["eventId"] as? String)
        case "handleDeepLink":
            if let url = args["url"] as? String { Angler.handleDeepLink(urlString: url) }
        case "setUserId":
            Angler.setUserId(args["userId"] as? String)
        case "setIdentifier":
            if let name = args["name"] as? String { Angler.setIdentifier(name, value: args["value"] as? String) }
        case "setApplicationTrackingEnabled":
            if let enabled = args["enabled"] as? Bool { Angler.setApplicationTrackingEnabled(enabled) }
        case "setEnabled":
            if let enabled = args["enabled"] as? Bool { Angler.setEnabled(enabled) }
        case "flush":
            Angler.flush()
        case "reset":
            Angler.reset()
        case "getClientId":
            Angler.getClientId { id in DispatchQueue.main.async { result(id) } }
            return
        default:
            result(FlutterMethodNotImplemented)
            return
        }
        result(nil)
    }

    /// The channel map → configuration with `wrapper = "flutter"`. Nil without workspaceId/token.
    static func configuration(_ o: [String: Any]) -> AnglerConfiguration? {
        guard let workspaceId = o["workspaceId"] as? String, !workspaceId.isEmpty,
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
        config.wrapper = "flutter"
        return config
    }

    private static func jsonObject(_ s: String) -> Any? {
        guard let data = s.data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: data)
    }
}
