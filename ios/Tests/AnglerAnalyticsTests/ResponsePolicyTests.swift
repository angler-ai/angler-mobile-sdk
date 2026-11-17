import XCTest
@testable import AnglerAnalytics

final class ResponsePolicyTests: XCTestCase {
    func testResponsePolicyFixtures() throws {
        let cases = try Fixtures.load("response-policy")
        XCTAssertEqual(cases.count, 14)
        for c in cases {
            var status: Int?
            if case .number(let n)? = c.input["status"] { status = Int(n) }
            guard case .number(let size)? = c.input["batchSize"] else { return XCTFail(c.name) }
            XCTAssertEqual(ResponsePolicy.decide(status: status, batchSize: Int(size)).rawValue, c.expected.stringValue, c.name)
        }
    }

    func testBackoffFixtures() throws {
        let cases = try Fixtures.load("backoff")
        XCTAssertEqual(cases.count, 7)
        for c in cases {
            guard case .number(let attempt)? = c.input["attempt"], case .number(let r)? = c.input["r"],
                  case .number(let expected) = c.expected else { return XCTFail(c.name) }
            XCTAssertEqual(Backoff.delay(attempt: Int(attempt), r: r), expected, accuracy: 1e-9, c.name)
        }
    }
}
