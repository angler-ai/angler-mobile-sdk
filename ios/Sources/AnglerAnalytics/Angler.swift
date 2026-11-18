import Foundation

/// Configuration for `Angler.configure`.
public struct AnglerConfiguration {
    public var workspaceId: String
    /// The workspace JWT, sent as `Authorization: Bearer <token>`.
    public var token: String
    /// `data.getangler.ai` in production, `dev-data.getangler.ai` for testing.
    public var domain: String
    /// Overrides `client_id`. Defaults to the install ID.
    public var clientId: String?
    /// Your App Store ID (`id1234567890` or `1234567890`), sent as the `app_id` device property
    /// (the value AppsFlyer reports). TikTok's app events need it.
    public var appStoreId: String?
    public var trackLifecycleEvents: Bool
    /// Number of queued events that triggers a flush.
    public var flushAt: Int
    /// Seconds between periodic flushes.
    public var flushInterval: TimeInterval
    /// When full, the oldest event is dropped.
    public var maxQueueSize: Int
    public var debugLogging: Bool
    /// `native`, or set by the React Native and Flutter wrappers.
    public var wrapper: String = "native"

    public init(workspaceId: String, token: String, domain: String = "data.getangler.ai", clientId: String? = nil,
                trackLifecycleEvents: Bool = true, flushAt: Int = 20, flushInterval: TimeInterval = 30,
                maxQueueSize: Int = 1000, debugLogging: Bool = false, appStoreId: String? = nil) {
        self.workspaceId = workspaceId
        self.token = token
        self.domain = domain
        self.clientId = clientId
        self.trackLifecycleEvents = trackLifecycleEvents
        self.flushAt = flushAt
        self.flushInterval = flushInterval
        self.maxQueueSize = maxQueueSize
        self.debugLogging = debugLogging
        self.appStoreId = appStoreId
    }
}

/// The Angler app SDK. Every method is safe to call from any thread and never throws.
public enum Angler {
    static let core: AnglerCore = {
        let queue = DispatchQueue(label: AnglerCore.queueLabel)
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        #if canImport(UIKit) && os(iOS)
        let backgroundTasks: BackgroundTasking? = UIKitBackgroundTasks()
        #else
        let backgroundTasks: BackgroundTasking? = nil
        #endif
        return AnglerCore(
            store: UserDefaultsStore(),
            clock: SystemClock(),
            queueDirectory: support.appendingPathComponent("AnglerAnalytics", isDirectory: true),
            transportFactory: { config in
                // AnglerCore.configure only gets this far once the endpoint has been validated.
                URLSessionTransport(endpoint: URLSessionTransport.endpoint(domain: config.domain, workspaceId: config.workspaceId)!,
                                    token: config.token)
            },
            adIds: SystemAdIdProvider(),
            device: { config, adTracking, appTracking in
                DeviceContext.collect(wrapper: config.wrapper, appStoreId: config.appStoreId, adTrackingEnabled: adTracking,
                                      applicationTrackingEnabled: appTracking)
            },
            uuid: { UUID().uuidString.lowercased() },
            scheduler: DispatchScheduler(queue: queue),
            lifecycle: .system,
            backgroundTasks: backgroundTasks,
            protectedData: .system,
            firebase: SystemFirebaseIdProvider(),
            queue: queue
        )
    }()

    /// Starts the SDK. Call once at launch; repeat calls with the same workspace do nothing.
    public static func configure(_ configuration: AnglerConfiguration) {
        // UIKit is main-thread only: read the screen size there (now, or soon if called elsewhere).
        if Thread.isMainThread {
            DeviceContext.captureScreenIfOnMain()
        } else {
            DispatchQueue.main.async { DeviceContext.captureScreenIfOnMain() }
        }
        core.configure(configuration)
    }

    /// Queues an event. Names data-api knows are sent as-is; others become `custom_event`.
    /// Dropped (with a warning) before `configure`.
    public static func track(_ name: String, data: [String: Any]? = nil, properties: [String: String]? = nil,
                             eventId: String? = nil) {
        core.track(name, data: data, properties: properties, eventId: eventId)
    }

    /// Queues a typed event: a standard name (or `.custom("name")`) with typed `data`.
    ///
    ///     Angler.track(.productAddedToCart, data: AnglerData(cartLine: AnglerCartLine(
    ///         merchandise: AnglerProductVariant(id: "variant-1", price: AnglerMoney(amount: 29, currencyCode: "USD")),
    ///         quantity: 1)))
    public static func track(_ event: AnglerEvent, data: AnglerData? = nil, properties: [String: String]? = nil,
                             eventId: String? = nil) {
        core.track(event, data: data, properties: properties, eventId: eventId)
    }

    /// Captures click IDs and the session URL. Works before `configure`.
    public static func handleDeepLink(_ url: URL) {
        core.handleDeepLink(urlString: url.absoluteString)
    }

    /// Like `handleDeepLink(_:)`, for URL strings (including ones `URL` would reject).
    public static func handleDeepLink(urlString: String) {
        core.handleDeepLink(urlString: urlString)
    }

    /// Sets the `customer_id` identifier; nil clears it.
    public static func setUserId(_ userId: String?) { core.setUserId(userId) }

    /// Sets a custom identifier such as `appsflyer_id`; nil removes it. Reserved names are ignored.
    public static func setIdentifier(_ name: String, value: String?) { core.setIdentifier(name, value: value) }

    /// Sent as `application_tracking_enabled` (default true).
    public static func setApplicationTrackingEnabled(_ enabled: Bool) { core.setApplicationTrackingEnabled(enabled) }

    /// `false` stops all collection and deletes queued events. Stored across launches.
    public static func setEnabled(_ enabled: Bool) { core.setEnabled(enabled) }

    /// Sends queued events now.
    public static func flush() { core.flush() }

    /// Clears the user ID, custom identifiers and attribution, and creates a new install ID.
    public static func reset() { core.reset() }
}
