import XCTest
@testable import AnglerAnalytics

final class ClickIdParserTests: XCTestCase {
    private func stringMap(_ v: JSONValue) -> [String: String] {
        (v.objectValue ?? [:]).compactMapValues { $0.stringValue }
    }

    func testDeeplinkFixtures() throws {
        let cases = try Fixtures.load("deeplinks")
        XCTAssertEqual(cases.count, 17)
        for c in cases {
            XCTAssertEqual(ClickIdParser.parse(url: c.input.stringValue!), stringMap(c.expected), c.name)
        }
    }

    func testInstallReferrerFixtures() throws {
        let cases = try Fixtures.load("install-referrer")
        XCTAssertEqual(cases.count, 5)
        for c in cases {
            XCTAssertEqual(ClickIdParser.parse(query: c.input.stringValue!), stringMap(c.expected), c.name)
        }
    }
}
