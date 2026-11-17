import XCTest
@testable import AnglerAnalytics

final class AttributionStoreTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_763_402_645.123)
    private let day: TimeInterval = 86_400

    func testClickIdExpiresAfter400Days() {
        let s = InMemoryStore()
        let clock = FixedClock(date: t0)
        AttributionStore(store: s, clock: clock).capture(clickIds: ["gclid": "g1"], url: nil)
        clock.date = t0.addingTimeInterval(399 * day)
        XCTAssertEqual(AttributionStore(store: s, clock: clock).snapshot().clickIds, ["gclid": "g1"])
        clock.date = t0.addingTimeInterval(401 * day)
        XCTAssertEqual(AttributionStore(store: s, clock: clock).snapshot().clickIds, [:])
    }

    func testNewValueReplacesOldAndResetsExpiry() {
        let clock = FixedClock(date: t0)
        let a = AttributionStore(store: InMemoryStore(), clock: clock)
        a.capture(clickIds: ["gclid": "g1"], url: nil)
        clock.date = t0.addingTimeInterval(300 * day)
        a.capture(clickIds: ["gclid": "g2"], url: nil)
        clock.date = t0.addingTimeInterval(500 * day)
        XCTAssertEqual(a.snapshot().clickIds, ["gclid": "g2"])
    }

    func testFbcKeptForSameFbclidReplacedForNew() {
        let clock = FixedClock(date: t0)
        let a = AttributionStore(store: InMemoryStore(), clock: clock)
        a.capture(clickIds: ["fbclid": "f1"], url: nil)
        XCTAssertEqual(a.snapshot().fbc, "fb.1.1763402645123.f1")
        clock.date = t0.addingTimeInterval(60)
        a.capture(clickIds: ["fbclid": "f1"], url: nil)
        XCTAssertEqual(a.snapshot().fbc, "fb.1.1763402645123.f1")
        a.capture(clickIds: ["fbclid": "f2"], url: nil)
        XCTAssertEqual(a.snapshot().fbc, "fb.1.1763402705123.f2")
    }

    func testFbcExpiresWithFbclid() {
        let s = InMemoryStore()
        let clock = FixedClock(date: t0)
        AttributionStore(store: s, clock: clock).capture(clickIds: ["fbclid": "f1"], url: nil)
        clock.date = t0.addingTimeInterval(401 * day)
        XCTAssertNil(AttributionStore(store: s, clock: clock).snapshot().fbc)
    }

    func testSessionURLClearedButClickIdsKept() {
        let a = AttributionStore(store: InMemoryStore(), clock: FixedClock(date: t0))
        a.capture(clickIds: ["gclid": "g"], url: "myapp://x?gclid=g")
        XCTAssertEqual(a.snapshot().url, "myapp://x?gclid=g")
        a.clearSessionURL()
        XCTAssertNil(a.snapshot().url)
        XCTAssertEqual(a.snapshot().clickIds, ["gclid": "g"])
    }

    func testCaptureWithNilURLKeepsExistingURL() {
        let a = AttributionStore(store: InMemoryStore(), clock: FixedClock(date: t0))
        a.capture(clickIds: [:], url: "myapp://x")
        a.capture(clickIds: ["gclid": "g"], url: nil)
        XCTAssertEqual(a.snapshot().url, "myapp://x")
    }

    func testClearRemovesEverything() {
        let a = AttributionStore(store: InMemoryStore(), clock: FixedClock(date: t0))
        a.capture(clickIds: ["fbclid": "f1", "gclid": "g"], url: "myapp://x")
        a.clear()
        XCTAssertEqual(a.snapshot(), AttributionSnapshot(clickIds: [:], fbc: nil, url: nil))
    }
}
