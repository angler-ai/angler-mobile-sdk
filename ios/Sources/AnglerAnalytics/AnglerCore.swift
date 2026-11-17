import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Keeps a background flush alive after the app leaves the foreground.
protocol BackgroundTasking {
    func begin() -> Int?
    func end(_ id: Int?)
}

#if canImport(UIKit) && os(iOS)
/// `beginBackgroundTask` / `endBackgroundTask`, always called on the main thread.
struct UIKitBackgroundTasks: BackgroundTasking {
    func begin() -> Int? {
        guard Thread.isMainThread else { return nil }
        return MainActor.assumeIsolated {
            let box = TaskIdBox()
            box.id = UIApplication.shared.beginBackgroundTask(withName: "ai.getangler.analytics.flush") {
                UIApplication.shared.endBackgroundTask(box.id)
            }
            return box.id == .invalid ? nil : box.id.rawValue
        }
    }

    /// Only touched on the main thread.
    private final class TaskIdBox: @unchecked Sendable {
        var id: UIBackgroundTaskIdentifier = .invalid
    }

    func end(_ id: Int?) {
        guard let id else { return }
        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                UIApplication.shared.endBackgroundTask(UIBackgroundTaskIdentifier(rawValue: id))
            }
        }
    }
}
#endif

/// All SDK state lives here and is only touched on `queue` (design §3).
final class AnglerCore {
    static let queueLabel = "ai.getangler.analytics"
    static let batchSize = 100
    static let src = "IOS"

    let queue: DispatchQueue
    private let queueKey = DispatchSpecificKey<Void>()

    private let clock: Clock
    private let queueDirectory: URL
    private let transportFactory: (AnglerConfiguration) -> Transport
    private let adIds: AdIdProviding
    private let device: (AnglerConfiguration, Bool, Bool) -> DeviceSnapshot
    private let uuid: () -> String
    private let scheduler: Scheduler
    private let lifecycleNotifications: LifecycleNotifications?
    private let backgroundTasks: BackgroundTasking?

    private let identity: IdentityStore
    private let attribution: AttributionStore

    private(set) var configuration: AnglerConfiguration?
    private(set) var eventQueue: EventQueue?
    private var flusher: Flusher?
    private var lifecycleObserver: LifecycleObserver?

    init(store: KeyValueStore,
         clock: Clock,
         queueDirectory: URL,
         transportFactory: @escaping (AnglerConfiguration) -> Transport,
         adIds: AdIdProviding,
         device: @escaping (AnglerConfiguration, Bool, Bool) -> DeviceSnapshot,
         uuid: @escaping () -> String,
         scheduler: Scheduler,
         lifecycle: LifecycleNotifications?,
         backgroundTasks: BackgroundTasking?,
         queue: DispatchQueue = DispatchQueue(label: AnglerCore.queueLabel)) {
        self.clock = clock
        self.queueDirectory = queueDirectory
        self.transportFactory = transportFactory
        self.adIds = adIds
        self.device = device
        self.uuid = uuid
        self.scheduler = scheduler
        self.lifecycleNotifications = lifecycle
        self.backgroundTasks = backgroundTasks
        self.queue = queue
        identity = IdentityStore(store: store)
        attribution = AttributionStore(store: store, clock: clock)
        queue.setSpecific(key: queueKey, value: ())
    }

    // MARK: - Public operations (any thread)

    func configure(_ config: AnglerConfiguration) {
        queue.async { self.doConfigure(config) }
    }

    func track(_ name: String, data: [String: Any]? = nil, properties: [String: String]? = nil, eventId: String? = nil) {
        // Everything time- or consent-dependent is read at call time (design §5 snapshot rule).
        let now = clock.now()
        let generatedId = uuid()
        let ad = adIds.current()
        var json: [String: JSONValue]?
        if let data {
            json = [:]
            for (k, v) in data {
                if let j = JSONValue.from(v) { json?[k] = j } else { Log.debug("dropping data['\(k)']: not representable as JSON") }
            }
        }
        let call = TrackCall(name: name, data: json, properties: properties, eventId: eventId)
        queue.async { self.record(call, at: now, generatedId: generatedId, idfa: ad.idfa, authorized: ad.authorized) }
    }

    func handleDeepLink(urlString: String) {
        queue.async {
            guard self.identity.isEnabled else { return }
            self.attribution.capture(clickIds: ClickIdParser.parse(url: urlString), url: urlString)
        }
    }

    func setUserId(_ userId: String?) {
        queue.async { self.identity.customerId = (userId?.isEmpty ?? true) ? nil : userId }
    }

    func setIdentifier(_ name: String, value: String?) {
        queue.async {
            if !self.identity.setIdentifier(name, value: value) {
                Log.warning("setIdentifier('\(name)') ignored: reserved or empty identifier name")
            }
        }
    }

    func setApplicationTrackingEnabled(_ enabled: Bool) {
        queue.async { self.identity.applicationTrackingEnabled = enabled }
    }

    func setEnabled(_ enabled: Bool) {
        queue.async {
            self.identity.isEnabled = enabled
            if !enabled { self.eventQueue?.removeAll() }
        }
    }

    func flush() {
        queue.async { self.flusher?.flush(completion: nil) }
    }

    func reset() {
        queue.async {
            self.identity.reset()
            self.attribution.clear()
        }
    }

    // MARK: - On queue

    private func doConfigure(_ config: AnglerConfiguration) {
        if let current = configuration {
            if current.workspaceId == config.workspaceId {
                Log.debug("configure: already configured; ignoring repeat call")
            } else {
                Log.warning("configure: already configured for workspace '\(current.workspaceId)'; ignoring '\(config.workspaceId)'")
            }
            return
        }
        guard !config.workspaceId.isEmpty, !config.token.isEmpty else {
            Log.warning("configure: workspaceId and token are required")
            return
        }
        Log.debugEnabled = config.debugLogging
        configuration = config

        let file = queueDirectory.appendingPathComponent("queue-\(Self.fileSafe(config.workspaceId)).json")
        let events = EventQueue(fileURL: file, maxSize: config.maxQueueSize)
        eventQueue = events
        flusher = Flusher(queue: events,
                          transport: QueueHoppingTransport(base: transportFactory(config), core: self),
                          src: Self.src,
                          batchSize: Self.batchSize,
                          scheduler: QueueHoppingScheduler(base: scheduler, queue: queue),
                          random: { Double.random(in: 0..<1) })

        let isNewInstall = identity.ensureAid().isNew
        if !identity.isEnabled {
            events.removeAll()
        } else if config.trackLifecycleEvents {
            let ad = adIds.current()
            if isNewInstall { record(TrackCall(name: "app_installed"), at: clock.now(), generatedId: uuid(), idfa: ad.idfa, authorized: ad.authorized) }
            record(TrackCall(name: "app_launched"), at: clock.now(), generatedId: uuid(), idfa: ad.idfa, authorized: ad.authorized)
        }

        if let notifications = lifecycleNotifications {
            lifecycleObserver = LifecycleObserver(
                clock: clock,
                notifications: notifications,
                onForeground: { [weak self] _, gap in self?.didEnterForeground(backgroundedFor: gap) },
                onBackground: { [weak self] in self?.didEnterBackground() }
            )
        }
        scheduleFlushTimer(interval: config.flushInterval)
    }

    private func record(_ call: TrackCall, at date: Date, generatedId: String, idfa: String?, authorized: Bool) {
        guard let config = configuration, let events = eventQueue else {
            Log.warning("track('\(call.name)') dropped: call Angler.configure first")
            return
        }
        guard identity.isEnabled else { return }
        guard !call.name.isEmpty else {
            Log.warning("track: event name is empty; dropped")
            return
        }
        let event = PayloadBuilder.buildEvent(
            call: call,
            generatedEventId: generatedId,
            timestamp: PayloadBuilder.timestamp(date),
            clientIdOverride: config.clientId,
            identity: IdentitySnapshot(aid: identity.ensureAid().aid, customerId: identity.customerId,
                                       adIdName: "idfa", adId: idfa, custom: identity.customIdentifiers),
            attribution: attribution.snapshot(),
            device: device(config, authorized, identity.applicationTrackingEnabled),
            referrer: nil
        )
        events.append(event)
        Log.debug("queued \(call.name) (\(events.count) in queue)")
        if events.count >= config.flushAt { flusher?.flush(completion: nil) }
    }

    private func scheduleFlushTimer(interval: TimeInterval) {
        guard interval > 0 else { return }
        QueueHoppingScheduler(base: scheduler, queue: queue).schedule(after: interval) { [weak self] in
            guard let self else { return }
            if (self.eventQueue?.count ?? 0) > 0 { self.flusher?.flush(completion: nil) }
            self.scheduleFlushTimer(interval: interval)
        }
    }

    /// Called on the posting thread (main for UIKit).
    private func didEnterBackground() {
        let task = backgroundTasks?.begin()
        queue.async {
            guard let flusher = self.flusher, (self.eventQueue?.count ?? 0) > 0 else {
                self.backgroundTasks?.end(task)
                return
            }
            flusher.flush { self.backgroundTasks?.end(task) }
        }
    }

    private func didEnterForeground(backgroundedFor gap: TimeInterval?) {
        let now = clock.now()
        let ad = adIds.current()
        let launchId = uuid()
        queue.async {
            guard let config = self.configuration, let gap, LifecycleObserver.isNewSession(backgroundedFor: gap) else { return }
            self.attribution.clearSessionURL()
            if config.trackLifecycleEvents {
                self.record(TrackCall(name: "app_launched"), at: now, generatedId: launchId, idfa: ad.idfa, authorized: ad.authorized)
            }
        }
    }

    fileprivate var isOnQueue: Bool { DispatchQueue.getSpecific(key: queueKey) != nil }

    private static func fileSafe(_ s: String) -> String {
        String(s.unicodeScalars.map { CharacterSet.alphanumerics.contains($0) || $0 == "-" || $0 == "_" ? Character($0) : "_" })
    }
}

extension TrackCall {
    init(name: String) { self.init(name: name, data: nil, properties: nil, eventId: nil) }
}

/// Delivers transport callbacks on the core queue (directly if already there).
private struct QueueHoppingTransport: Transport {
    let base: Transport
    weak var core: AnglerCore?

    func send(_ body: Data, completion: @escaping (Int?) -> Void) {
        base.send(body) { status in
            guard let core else { return }
            if core.isOnQueue { completion(status) } else { core.queue.async { completion(status) } }
        }
    }
}

/// Runs scheduled work on the core queue.
private struct QueueHoppingScheduler: Scheduler {
    let base: Scheduler
    let queue: DispatchQueue

    func schedule(after delay: TimeInterval, _ work: @escaping () -> Void) {
        base.schedule(after: delay) { [queue] in queue.async(execute: work) }
    }
}
