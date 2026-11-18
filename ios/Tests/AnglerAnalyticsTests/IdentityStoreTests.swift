import XCTest
@testable import AnglerAnalytics

final class IdentityStoreTests: XCTestCase {
    func testAidCreatedOnceAndPersisted() {
        let s = InMemoryStore()
        let first = IdentityStore(store: s).ensureAid()
        let second = IdentityStore(store: s).ensureAid()
        XCTAssertTrue(first.isNew)
        XCTAssertFalse(second.isNew)
        XCTAssertEqual(first.aid, second.aid)
        XCTAssertEqual(first.aid, first.aid.lowercased())
    }

    func testReservedIdentifierRejected() {
        let ids = IdentityStore(store: InMemoryStore())
        for name in ["aid", "customer_id", "idfa", "gaid", "gclid", "sccid", "epik"] {
            XCTAssertFalse(ids.setIdentifier(name, value: "x"), name)
        }
        XCTAssertTrue(ids.customIdentifiers.isEmpty)
    }

    func testCustomIdentifierSetAndRemoved() {
        let s = InMemoryStore()
        XCTAssertTrue(IdentityStore(store: s).setIdentifier("appsflyer_id", value: "af-1"))
        XCTAssertEqual(IdentityStore(store: s).customIdentifiers, ["appsflyer_id": "af-1"])
        XCTAssertTrue(IdentityStore(store: s).setIdentifier("appsflyer_id", value: nil))
        XCTAssertTrue(IdentityStore(store: s).customIdentifiers.isEmpty)
    }

    func testFlagsDefaultTrueAndPersist() {
        let s = InMemoryStore()
        let ids = IdentityStore(store: s)
        XCTAssertTrue(ids.isEnabled)
        XCTAssertTrue(ids.applicationTrackingEnabled)
        ids.isEnabled = false
        ids.applicationTrackingEnabled = false
        XCTAssertFalse(IdentityStore(store: s).isEnabled)
        XCTAssertFalse(IdentityStore(store: s).applicationTrackingEnabled)
    }

    func testResetRotatesAidAndClearsUser() {
        let s = InMemoryStore()
        let ids = IdentityStore(store: s)
        let aid = ids.ensureAid().aid
        ids.customerId = "cust-1"
        _ = ids.setIdentifier("appsflyer_id", value: "af-1")
        ids.reset()
        XCTAssertNil(ids.customerId)
        XCTAssertTrue(ids.customIdentifiers.isEmpty)
        let after = IdentityStore(store: s).ensureAid()
        XCTAssertFalse(after.isNew)
        XCTAssertNotEqual(after.aid, aid)
    }
}
