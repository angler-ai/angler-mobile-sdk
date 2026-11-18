import XCTest
@testable import AnglerAnalytics

final class StandardEventTests: XCTestCase {
    func testStandardEvents() {
        XCTAssertTrue(StandardEvent.isStandard("product_viewed"))
        XCTAssertTrue(StandardEvent.isStandard("app_installed"))
        XCTAssertFalse(StandardEvent.isStandard("level_up"))
        XCTAssertEqual(StandardEvent.names.count, 19)
    }

    func testFixturesLoad() throws {
        XCTAssertFalse(try Fixtures.load("deeplinks").isEmpty)
    }
}
