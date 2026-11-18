import XCTest
@testable import AnglerAnalytics

final class AdIdProviderTests: XCTestCase {
    func testZerosDropped() {
        XCTAssertNil(AdIdProvider.normalize(idfa: "00000000-0000-0000-0000-000000000000", authorized: true))
    }

    func testRequiresAuthorization() {
        XCTAssertNil(AdIdProvider.normalize(idfa: "AAAA-1", authorized: false))
        XCTAssertEqual(AdIdProvider.normalize(idfa: "AAAA-1", authorized: true), "AAAA-1")
    }

    func testNilAndEmpty() {
        XCTAssertNil(AdIdProvider.normalize(idfa: nil, authorized: true))
        XCTAssertNil(AdIdProvider.normalize(idfa: "", authorized: true))
    }

    func testSystemProviderNeverSendsIdfaWithoutAuthorization() {
        // Test hosts never grant ATT, so the system provider must report no IDFA.
        let current = SystemAdIdProvider().current()
        if !current.authorized { XCTAssertNil(current.idfa) }
    }
}
