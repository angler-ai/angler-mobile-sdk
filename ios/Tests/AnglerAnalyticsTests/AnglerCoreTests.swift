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

    private func makeCore(transport: FakeTransport? = nil, center: NotificationCenter? = nil,
                          isActive: (() -> Bool)? = nil, protectedData: ProtectedDataGate? = nil,
                          firebase: FirebaseIdProviding = NoFirebaseIdProvider()) -> AnglerCore {
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
            lifecycle: LifecycleNotifications(center: center ?? self.center, background: .init("bg"),
                                              foreground: .init("fg"), isActive: isActive),
            backgroundTasks: nil,
            protectedData: protectedData,
            firebase: firebase
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

    private func foreground(_ c: NotificationCenter? = nil) { (c ?? center).post(name: .init("fg"), object: nil) }
    private func background(_ c: NotificationCenter? = nil) { (c ?? center).post(name: .init("bg"), object: nil) }

    func testInstalledAtConfigureLaunchedOnFirstForeground() {
        transport.defaultStatus = nil
        let core = makeCore()
        core.configure(config(lifecycle: true))
        XCTAssertEqual(names(core), ["app_installed"])
        foreground()
        XCTAssertEqual(names(core), ["app_installed", "app_launched"])
    }

    func testBackgroundOnlyLaunchSendsNoAppLaunched() {
        transport.defaultStatus = nil
        let first = makeCore()
        first.configure(config(lifecycle: true))
        foreground()
        first.waitUntilIdle()
        // e.g. a silent push wakes the app: configure runs, the app never comes to the foreground.
        let second = makeCore(center: NotificationCenter())
        second.configure(config(lifecycle: true))
        XCTAssertEqual(names(second), ["app_installed", "app_launched"])
    }

    func testSecondConfigureOnlyLaunched() {
        transport.defaultStatus = nil
        let first = makeCore()
        first.configure(config(lifecycle: true))
        foreground()
        first.waitUntilIdle()
        let other = NotificationCenter()
        let second = makeCore(center: other)
        second.configure(config(lifecycle: true))
        foreground(other)
        // Same queue file: the first core's two events are still there, plus one launch.
        XCTAssertEqual(names(second), ["app_installed", "app_launched", "app_launched"])
    }

    func testRepeatConfigureIsNoOp() {
        transport.defaultStatus = nil
        let core = makeCore()
        core.configure(config(lifecycle: true))
        core.configure(config(lifecycle: true))
        foreground()
        XCTAssertEqual(names(core), ["app_installed", "app_launched"])
    }

    func testBecomingActiveWithoutBackgroundIsNotALaunch() {
        transport.defaultStatus = nil
        let core = makeCore()
        core.configure(config(lifecycle: true))
        foreground()
        foreground() // e.g. Control Center or a system alert dismissed
        XCTAssertEqual(names(core), ["app_installed", "app_launched"])
    }

    func testLaunchCarriesDeepLinkDeliveredAfterConfigure() throws {
        transport.defaultStatus = nil
        let core = makeCore()
        core.configure(config(lifecycle: true))
        core.handleDeepLink(urlString: "myapp://p/1?gclid=g1") // onOpenURL runs after configure
        foreground()
        let launched = try XCTUnwrap(core.queuedBodies().last)
        XCTAssertEqual(launched["event_name"], .string("app_launched"))
        XCTAssertEqual(identifiers(launched)["gclid"], "g1")
        XCTAssertEqual(launched["url"], .string("myapp://p/1?gclid=g1"))
    }

    func testConfigureWhileAlreadyActiveRecordsLaunch() {
        transport.defaultStatus = nil
        // React Native and Flutter call configure after the app is already active.
        let core = makeCore(isActive: { true })
        core.configure(config(lifecycle: true))
        core.waitUntilIdle()
        RunLoop.main.run(until: Date().addingTimeInterval(0.1)) // the active check hops to main
        XCTAssertEqual(names(core), ["app_installed", "app_launched"])
        foreground()
        XCTAssertEqual(names(core), ["app_installed", "app_launched"], "the observer's own event isn't a second launch")
    }

    // A previous process went to the background and was killed; a new process starts later.
    private func previousSession(url: String, backgroundedAfter: TimeInterval = 0) {
        let other = NotificationCenter()
        let old = makeCore(center: other)
        old.configure(config(lifecycle: true))
        old.handleDeepLink(urlString: url)
        foreground(other)
        old.waitUntilIdle()
        clock.date = clock.date.addingTimeInterval(backgroundedAfter)
        background(other)
        old.waitUntilIdle()
    }

    func testColdStartAfterLongBackgroundClearsPreviousSessionURL() throws {
        transport.defaultStatus = nil
        previousSession(url: "myapp://old?gclid=g1")
        clock.date = clock.date.addingTimeInterval(1800)
        let core = makeCore()
        core.configure(config(lifecycle: true))
        foreground()
        let launched = try XCTUnwrap(core.queuedBodies().last)
        XCTAssertEqual(launched["event_name"], .string("app_launched"))
        XCTAssertNil(launched["url"])
        XCTAssertEqual(identifiers(launched)["gclid"], "g1", "click IDs outlive the session")
    }

    func testColdStartAfterShortBackgroundKeepsURL() throws {
        transport.defaultStatus = nil
        previousSession(url: "myapp://old?gclid=g1")
        clock.date = clock.date.addingTimeInterval(1799)
        let core = makeCore()
        core.configure(config(lifecycle: true))
        foreground()
        XCTAssertEqual(try XCTUnwrap(core.queuedBodies().last)["url"], .string("myapp://old?gclid=g1"))
    }

    func testColdStartKeepsLinkThatOpenedTheApp() throws {
        transport.defaultStatus = nil
        previousSession(url: "myapp://old?gclid=g1")
        clock.date = clock.date.addingTimeInterval(3600)
        let core = makeCore()
        core.configure(config(lifecycle: true))
        core.handleDeepLink(urlString: "myapp://new?gclid=g2")
        foreground()
        let launched = try XCTUnwrap(core.queuedBodies().last)
        XCTAssertEqual(launched["url"], .string("myapp://new?gclid=g2"))
        XCTAssertEqual(identifiers(launched)["gclid"], "g2")
    }

    func testLifecycleEventsOffQueuesNothing() {
        let core = makeCore()
        core.configure(config(lifecycle: false))
        XCTAssertEqual(names(core), [])
    }

    // MARK: track

    func testConfigureWithInvalidDomainIsIgnored() {
        let core = makeCore()
        core.configure(AnglerConfiguration(workspaceId: "ws", token: "tok", domain: "not a domain", trackLifecycleEvents: false))
        core.track("product_viewed")
        XCTAssertNil(core.configuration(sync: ()), "an endpoint that can't be built must not configure the SDK")
        XCTAssertEqual(core.queuedBodies().count, 0)
    }

    func testConfigureWaitsForProtectedData() {
        transport.defaultStatus = nil
        // A background launch before the first unlock after a reboot: UserDefaults reads as empty.
        var available = false
        let gateCenter = NotificationCenter()
        let core = makeCore(protectedData: ProtectedDataGate(center: gateCenter, becameAvailable: .init("unlocked"),
                                                             isAvailable: { available }))
        core.configure(config(lifecycle: true))
        core.track("product_viewed")
        XCTAssertNil(core.configuration(sync: ()), "not configured while the device is locked")
        XCTAssertNil(store.string("aid"), "no install ID minted while locked")

        available = true
        gateCenter.post(name: .init("unlocked"), object: nil)
        core.waitUntilIdle()
        XCTAssertNotNil(core.configuration(sync: ()))
        XCTAssertEqual(names(core), ["app_installed"])
        gateCenter.post(name: .init("unlocked"), object: nil)
        core.configure(config(lifecycle: true))
        XCTAssertEqual(names(core), ["app_installed"], "configures once")
    }

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

    func testTrackTypedEvent() throws {
        transport.defaultStatus = nil
        let core = makeCore()
        core.configure(config())
        core.track(.productAddedToCart, data: TypedDataCases.build("cart_line_added"), properties: ["a": "1"])
        core.track(.custom("level_up"))
        let events = core.queuedBodies()
        XCTAssertEqual(events[0]["event_name"], .string("product_added_to_cart"))
        var expected = try XCTUnwrap(Fixtures.load("typed-data").first { $0.name == "cart_line_added" }?.expected.objectValue)
        expected["customData"] = .array([.object(["name": .string("a"), "value": .string("1")])])
        XCTAssertEqual(events[0]["data"], .object(expected))
        XCTAssertEqual(events[1]["event_name"], .string("custom_event"))
        XCTAssertEqual(events[1]["custom_event_name"], .string("level_up"))
    }

    private struct FakeFirebase: FirebaseIdProviding {
        var id: String?
        func appInstanceId() -> String? { id }
    }

    func testFirebaseAppInstanceIdIsSentWhenAvailable() throws {
        transport.defaultStatus = nil
        let core = makeCore(firebase: FakeFirebase(id: "fb-123"))
        core.configure(config())
        core.track("product_viewed")
        XCTAssertEqual(identifiers(try XCTUnwrap(core.queuedBodies().first))["firebase_app_instance_id"], "fb-123")
    }

    func testNoFirebaseMeansNoFirebaseIdentifier() throws {
        transport.defaultStatus = nil
        let core = makeCore()
        core.configure(config())
        core.track("product_viewed")
        XCTAssertNil(identifiers(try XCTUnwrap(core.queuedBodies().first))["firebase_app_instance_id"])
    }

    func testHostSetFirebaseIdWins() throws {
        transport.defaultStatus = nil
        let core = makeCore(firebase: FakeFirebase(id: "auto"))
        core.configure(config())
        core.setIdentifier("firebase_app_instance_id", value: "manual")
        core.track("product_viewed")
        XCTAssertEqual(identifiers(try XCTUnwrap(core.queuedBodies().first))["firebase_app_instance_id"], "manual")
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
        XCTAssertEqual(names(core), ["app_installed"])
    }

    // MARK: client ID

    private func clientId(_ core: AnglerCore) -> String?? {
        let done = expectation(description: "getClientId")
        var result: String??
        core.getClientId { result = .some($0); done.fulfill() }
        wait(for: [done], timeout: 5)
        return result
    }

    func testClientIdIsNilBeforeConfigure() {
        let core = makeCore()
        XCTAssertEqual(clientId(core), .some(nil))
        core.configure(config(lifecycle: true))
        XCTAssertEqual(names(core), ["app_installed"], "asking first doesn't use up the install event")
    }

    func testClientIdIsTheInstallIdEventsCarry() throws {
        transport.defaultStatus = nil
        let core = makeCore()
        core.configure(config())
        core.track("product_viewed")
        let sent = try XCTUnwrap(core.queuedBodies().last?["client_id"]?.stringValue)
        XCTAssertEqual(clientId(core), .some(sent))
        XCTAssertEqual(identifiers(core.queuedBodies().last!)["aid"], sent)
    }

    func testClientIdPrefersTheConfiguredOverride() {
        let core = makeCore()
        core.configure(config(clientId: "crm-1"))
        XCTAssertEqual(clientId(core), .some("crm-1"))
    }

    func testClientIdChangesOnResetAndIsNilWhileDisabled() throws {
        let core = makeCore()
        core.configure(config())
        let before = try XCTUnwrap(clientId(core) ?? nil)
        core.reset()
        let after = try XCTUnwrap(clientId(core) ?? nil)
        XCTAssertNotEqual(before, after)
        core.setEnabled(false)
        XCTAssertEqual(clientId(core), .some(nil))
        core.setEnabled(true)
        XCTAssertEqual(clientId(core), .some(after))
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
        foreground()
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
    func configuration(sync: Void) -> AnglerConfiguration? { queue.sync { configuration } }
    func waitUntilIdle() { queue.sync {} }
    func queuedBodies() -> [JSONValue] {
        queue.sync { eventQueue?.peek(Int.max).map(\.body) ?? [] }
    }
}
