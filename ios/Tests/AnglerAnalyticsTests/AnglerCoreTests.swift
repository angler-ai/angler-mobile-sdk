import XCTest
@testable import AnglerAnalytics

final class AnglerCoreTests: XCTestCase {
    private var dir: URL!
    private var store: InMemoryStore!
    private var clock: FixedClock!
    private var transport: FakeTransport!
    private var scheduler: ManualScheduler!
    private var center: NotificationCenter!
    private var adIds: FakeAdIds!
    private var counter = 0
    private let t0 = Date(timeIntervalSince1970: 1_763_402_645.123)

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        store = InMemoryStore()
        clock = FixedClock(date: t0)
        transport = FakeTransport()
        scheduler = ManualScheduler()
        center = NotificationCenter()
        adIds = FakeAdIds()
    }

    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: dir) }

    private func makeCore(transport: FakeTransport? = nil) -> AnglerCore {
        let lock = NSLock()
        return AnglerCore(
            store: store,
            clock: clock,
            queueDirectory: dir,
            transportFactory: { [unowned self] _ in transport ?? self.transport },
            adIds: adIds,
            device: { _, adTracking, appTracking in
                DeviceSnapshot(properties: [DeviceProperty(name: "os", value: "ios"),
                                            DeviceProperty(name: "advertiser_tracking_enabled", value: adTracking ? "1" : "0"),
                                            DeviceProperty(name: "application_tracking_enabled", value: appTracking ? "1" : "0")],
                               userAgent: "AnglerAnalytics/test (iOS 17.4; iPhone15,2; native)")
            },
            uuid: { [unowned self] in lock.lock(); defer { lock.unlock() }; self.counter += 1; return "uuid-\(self.counter)" },
            scheduler: scheduler,
            lifecycle: LifecycleNotifications(center: center, background: .init("bg"), foreground: .init("fg")),
            backgroundTasks: nil
        )
    }

    private func config(lifecycle: Bool = false, flushAt: Int = 20, clientId: String? = nil) -> AnglerConfiguration {
        AnglerConfiguration(workspaceId: "ws", token: "tok", clientId: clientId, trackLifecycleEvents: lifecycle, flushAt: flushAt)
    }

    private func names(_ core: AnglerCore) -> [String] {
        core.queuedBodies().map { e in
            e["custom_event_name"]?.stringValue ?? e["event_name"]!.stringValue!
        }
    }

    private func identifiers(_ event: JSONValue) -> [String: String] {
        var out: [String: String] = [:]
        for i in event["identifiers"]?.arrayValue ?? [] { out[i["name"]!.stringValue!] = i["value"]!.stringValue! }
        return out
    }

    // MARK: lifecycle events

    func testFirstConfigureQueuesInstalledThenLaunched() {
        transport.defaultStatus = nil
        let core = makeCore()
        core.configure(config(lifecycle: true))
        XCTAssertEqual(names(core), ["app_installed", "app_launched"])
    }

    func testSecondConfigureOnlyLaunched() {
        transport.defaultStatus = nil
        let first = makeCore()
        first.configure(config(lifecycle: true))
        first.waitUntilIdle()
        let second = makeCore()
        second.configure(config(lifecycle: true))
        // Same queue file: the first core's two events are still there, plus one launch.
        XCTAssertEqual(names(second), ["app_installed", "app_launched", "app_launched"])
    }

    func testRepeatConfigureIsNoOp() {
        transport.defaultStatus = nil
        let core = makeCore()
        core.configure(config(lifecycle: true))
        core.configure(config(lifecycle: true))
        XCTAssertEqual(names(core), ["app_installed", "app_launched"])
    }

    func testLifecycleEventsOffQueuesNothing() {
        let core = makeCore()
        core.configure(config(lifecycle: false))
        XCTAssertEqual(names(core), [])
    }

    // MARK: track

    func testTrackBeforeConfigureDropped() {
        let core = makeCore()
        core.track("product_viewed")
        core.configure(config())
        XCTAssertEqual(names(core), [])
    }

    func testTrackBuildsEventAtCallTime() throws {
        transport.defaultStatus = nil
        let core = makeCore()
        core.configure(config())
        core.track("level_up", data: ["productVariant": ["id": "v1"], "foo": 1], properties: ["a": "1"])
        let e = try XCTUnwrap(core.queuedBodies().first)
        XCTAssertEqual(e["event_name"], .string("custom_event"))
        XCTAssertEqual(e["event_id"], .string("uuid-1"))
        XCTAssertEqual(e["timestamp"], .string("2025-11-17T18:04:05.123Z"))
        XCTAssertEqual(e["data"], .object(["productVariant": .object(["id": .string("v1")]),
                                           "customData": .array([.object(["name": .string("a"), "value": .string("1")])])]))
        XCTAssertEqual(identifiers(e)["aid"], e["client_id"]?.stringValue)
    }

    func testClientIdOverride() throws {
        let core = makeCore()
        transport.defaultStatus = nil
        core.configure(config(clientId: "crm-42"))
        core.track("product_viewed")
        XCTAssertEqual(try XCTUnwrap(core.queuedBodies().first)["client_id"], .string("crm-42"))
    }

    func testDeepLinkBeforeConfigureIsAttributed() throws {
        transport.defaultStatus = nil
        let core = makeCore()
        core.handleDeepLink(urlString: "myapp://x?gclid=g1")
        core.configure(config())
        core.track("product_viewed")
        let e = try XCTUnwrap(core.queuedBodies().first)
        XCTAssertEqual(identifiers(e)["gclid"], "g1")
        XCTAssertEqual(e["url"], .string("myapp://x?gclid=g1"))
    }

    func testFbclidDeepLinkSetsFbc() throws {
        transport.defaultStatus = nil
        let core = makeCore()
        core.configure(config())
        core.handleDeepLink(urlString: "myapp://x?fbclid=f1")
        core.track("product_viewed")
        XCTAssertEqual(try XCTUnwrap(core.queuedBodies().first)["fbc"], .string("fb.1.1763402645123.f1"))
    }

    func testQueuedEventUnaffectedByLaterSetUserId() throws {
        transport.defaultStatus = nil
        let core = makeCore()
        core.configure(config())
        core.track("product_viewed")
        core.setUserId("cust-1")
        core.track("product_viewed")
        let events = core.queuedBodies()
        XCTAssertNil(identifiers(events[0])["customer_id"])
        XCTAssertEqual(identifiers(events[1])["customer_id"], "cust-1")
    }

    func testReservedSetIdentifierIgnored() throws {
        transport.defaultStatus = nil
        let core = makeCore()
        core.configure(config())
        core.setIdentifier("gclid", value: "spoof")
        core.setIdentifier("appsflyer_id", value: "af-1")
        core.track("product_viewed")
        let ids = identifiers(try XCTUnwrap(core.queuedBodies().first))
        XCTAssertNil(ids["gclid"])
        XCTAssertEqual(ids["appsflyer_id"], "af-1")
    }

    func testIdfaOnlyWhenAuthorized() throws {
        transport.defaultStatus = nil
        let core = makeCore()
        core.configure(config())
        adIds.value = ("AAAA-1111", false)
        core.track("product_viewed")
        adIds.value = ("00000000-0000-0000-0000-000000000000", true)
        core.track("product_viewed")
        adIds.value = ("AAAA-1111", true)
        core.track("product_viewed")
        let events = core.queuedBodies()
        XCTAssertNil(identifiers(events[0])["idfa"])
        XCTAssertNil(identifiers(events[1])["idfa"])
        XCTAssertEqual(identifiers(events[2])["idfa"], "AAAA-1111")
        func ate(_ e: JSONValue) -> String? {
            e["device_properties"]?.arrayValue?.first { $0["name"] == .string("advertiser_tracking_enabled") }?["value"]?.stringValue
        }
        XCTAssertEqual(ate(events[0]), "0")
        XCTAssertEqual(ate(events[2]), "1")
    }

    func testApplicationTrackingFlag() throws {
        transport.defaultStatus = nil
        let core = makeCore()
        core.configure(config())
        core.setApplicationTrackingEnabled(false)
        core.track("product_viewed")
        let e = try XCTUnwrap(core.queuedBodies().first)
        XCTAssertTrue(e["device_properties"]!.arrayValue!.contains(
            .object(["name": .string("application_tracking_enabled"), "value": .string("0")])))
    }

    // MARK: opt-out and reset

    func testSetEnabledFalseClearsQueueAndDropsTracks() {
        transport.defaultStatus = nil
        let core = makeCore()
        core.configure(config())
        core.track("product_viewed")
        core.setEnabled(false)
        core.track("product_viewed")
        XCTAssertEqual(core.queuedBodies().count, 0)
        core.waitUntilIdle()
        let next = makeCore()
        next.configure(config(lifecycle: true))
        next.track("product_viewed")
        XCTAssertEqual(next.queuedBodies().count, 0, "opt-out survives a new launch")
        next.setEnabled(true)
        next.track("product_viewed")
        XCTAssertEqual(next.queuedBodies().count, 1)
    }

    func testResetRotatesAidWithoutInstallEvent() throws {
        transport.defaultStatus = nil
        let core = makeCore()
        core.configure(config(lifecycle: true))
        core.setUserId("cust-1")
        core.handleDeepLink(urlString: "myapp://x?gclid=g1&fbclid=f1")
        core.track("product_viewed")
        let before = identifiers(core.queuedBodies().last!)["aid"]
        core.reset()
        core.track("product_viewed")
        let e = try XCTUnwrap(core.queuedBodies().last)
        let ids = identifiers(e)
        XCTAssertNotEqual(ids["aid"], before)
        XCTAssertEqual(Set(ids.keys), ["aid"])
        XCTAssertNil(e["fbc"])
        XCTAssertNil(e["url"])
        XCTAssertEqual(names(core).filter { $0 == "app_installed" }.count, 1)
    }

    func testResetBeforeFirstConfigureKeepsInstallEvent() {
        transport.defaultStatus = nil
        let core = makeCore()
        core.reset()
        core.configure(config(lifecycle: true))
        XCTAssertEqual(names(core), ["app_installed", "app_launched"])
    }

    // MARK: delivery

    func testNewCoreSameDirectorySendsOldEvents() {
        let offline = FakeTransport()
        offline.defaultStatus = nil
        let a = makeCore(transport: offline)
        a.configure(config())
        (0..<3).forEach { _ in a.track("product_viewed") }
        a.flush()
        a.waitUntilIdle()
        XCTAssertEqual(a.queuedBodies().count, 3)

        let b = makeCore()
        b.configure(config())
        b.flush()
        b.waitUntilIdle()
        XCTAssertEqual(transport.deliveredEventIds().count, 3)
        XCTAssertEqual(b.queuedBodies().count, 0)
    }

    func testConcurrentTracks() {
        transport.defaultStatus = nil
        let core = makeCore()
        core.configure(AnglerConfiguration(workspaceId: "ws", token: "tok", trackLifecycleEvents: false, flushAt: 5000))
        DispatchQueue.concurrentPerform(iterations: 8) { t in
            for i in 0..<125 { core.track("e_\(t)_\(i)") }
        }
        let events = core.queuedBodies()
        XCTAssertEqual(events.count, 1000)
        XCTAssertEqual(Set(events.compactMap { $0["event_id"]?.stringValue }).count, 1000)
    }

    func testFlushAtTriggersSend() {
        let core = makeCore()
        core.configure(config(flushAt: 20))
        (0..<19).forEach { _ in core.track("product_viewed") }
        core.waitUntilIdle()
        XCTAssertEqual(transport.requestCount, 0)
        core.track("product_viewed")
        core.waitUntilIdle()
        XCTAssertEqual(transport.requestCount, 1)
        XCTAssertEqual(transport.batchSizes(), [20])
    }

    func testFlushIntervalTriggersSend() {
        let core = makeCore()
        core.configure(config())
        core.track("product_viewed")
        core.waitUntilIdle()
        scheduler.advance(by: 29)
        core.waitUntilIdle()
        XCTAssertEqual(transport.requestCount, 0)
        scheduler.advance(by: 1)
        core.waitUntilIdle()
        XCTAssertEqual(transport.requestCount, 1)
        core.track("product_viewed")
        scheduler.advance(by: 30)
        core.waitUntilIdle()
        XCTAssertEqual(transport.requestCount, 2, "the timer repeats")
    }

    func testBackgroundTriggersFlush() {
        let core = makeCore()
        core.configure(config())
        core.track("product_viewed")
        core.waitUntilIdle()
        center.post(name: .init("bg"), object: nil)
        core.waitUntilIdle()
        XCTAssertEqual(transport.requestCount, 1)
    }

    func testRequestUsesIOSSrc() {
        let core = makeCore()
        core.configure(config())
        core.track("product_viewed")
        core.flush()
        core.waitUntilIdle()
        XCTAssertEqual(transport.bodies.first?["src"], .string("IOS"))
    }

    // MARK: sessions

    func testForegroundAfter30MinStartsSessionAndClearsURL() {
        transport.defaultStatus = nil
        let core = makeCore()
        core.configure(config(lifecycle: true))
        core.handleDeepLink(urlString: "myapp://x?gclid=g1")
        core.waitUntilIdle()

        center.post(name: .init("bg"), object: nil)
        clock.date = clock.date.addingTimeInterval(1799)
        center.post(name: .init("fg"), object: nil)
        core.track("product_viewed")
        XCTAssertEqual(names(core), ["app_installed", "app_launched", "product_viewed"])
        XCTAssertEqual(core.queuedBodies().last?["url"], .string("myapp://x?gclid=g1"))

        center.post(name: .init("bg"), object: nil)
        clock.date = clock.date.addingTimeInterval(1800)
        center.post(name: .init("fg"), object: nil)
        core.track("product_viewed")
        XCTAssertEqual(names(core), ["app_installed", "app_launched", "product_viewed", "app_launched", "product_viewed"])
        XCTAssertNil(core.queuedBodies().last?["url"])
        XCTAssertEqual(identifiers(core.queuedBodies().last!)["gclid"], "g1", "click IDs outlive the session")
    }
}

final class FakeAdIds: AdIdProviding {
    var value: (String?, Bool) = (nil, false)
    func current() -> (idfa: String?, authorized: Bool) {
        (AdIdProvider.normalize(idfa: value.0, authorized: value.1), value.1)
    }
}

extension AnglerCore {
    func waitUntilIdle() { queue.sync {} }
    func queuedBodies() -> [JSONValue] {
        queue.sync { eventQueue?.peek(Int.max).map(\.body) ?? [] }
    }
}
