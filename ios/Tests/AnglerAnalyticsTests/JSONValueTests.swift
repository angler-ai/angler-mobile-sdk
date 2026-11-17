import XCTest
@testable import AnglerAnalytics

final class JSONValueTests: XCTestCase {
    func testBoolNSNumberStaysBool() {
        XCTAssertEqual(JSONValue.from(NSNumber(value: true)), .bool(true))
    }

    func testIntBecomesNumber() {
        XCTAssertEqual(JSONValue.from(3), .number(3))
    }

    func testUnsupportedValueDroppedInsideObject() {
        XCTAssertEqual(JSONValue.from(["a": 1, "d": Date()] as [String: Any]), .object(["a": .number(1)]))
    }

    func testEncodedIsCompactWithSortedKeys() {
        let v: JSONValue = .object(["b": .number(1), "a": .array([.string("x"), .null, .bool(false)])])
        XCTAssertEqual(String(data: v.encoded(), encoding: .utf8), #"{"a":["x",null,false],"b":1}"#)
    }

    func testDecodeRoundTrip() throws {
        let v: JSONValue = .object(["n": .number(1.5), "s": .string("é"), "o": .object([:])])
        XCTAssertEqual(try JSONDecoder().decode(JSONValue.self, from: v.encoded()), v)
    }
}
