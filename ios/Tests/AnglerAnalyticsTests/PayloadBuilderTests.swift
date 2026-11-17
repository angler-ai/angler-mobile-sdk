import XCTest
@testable import AnglerAnalytics

final class PayloadBuilderTests: XCTestCase {
    private func strings(_ v: JSONValue?) -> [String: String] {
        (v?.objectValue ?? [:]).compactMapValues { $0.stringValue }
    }

    private func optString(_ v: JSONValue?) -> String? { v?.stringValue }

    func testPayloadFixtures() throws {
        let cases = try Fixtures.load("payloads")
        XCTAssertEqual(cases.count, 11)
        for c in cases {
            let i = c.input
            let call = i["call"]!
            let identity = i["identity"]!
            let attribution = i["attribution"]!
            let device = i["device"]!
            let result = PayloadBuilder.buildEvent(
                call: TrackCall(
                    name: call["name"]!.stringValue!,
                    data: call["data"]?.objectValue,
                    properties: strings(call["properties"]),
                    eventId: optString(call["eventId"])
                ),
                generatedEventId: i["generatedEventId"]!.stringValue!,
                timestamp: i["timestamp"]!.stringValue!,
                clientIdOverride: optString(i["clientIdOverride"]),
                identity: IdentitySnapshot(
                    aid: identity["aid"]!.stringValue!,
                    customerId: optString(identity["customerId"]),
                    adIdName: identity["adIdName"]!.stringValue!,
                    adId: optString(identity["adId"]),
                    custom: strings(identity["custom"])
                ),
                attribution: AttributionSnapshot(
                    clickIds: strings(attribution["clickIds"]),
                    fbc: optString(attribution["fbc"]),
                    url: optString(attribution["url"])
                ),
                device: DeviceSnapshot(
                    properties: device["properties"]!.arrayValue!.map {
                        let pair = $0.arrayValue!
                        return DeviceProperty(name: pair[0].stringValue!, value: pair[1].stringValue!)
                    },
                    userAgent: device["userAgent"]!.stringValue!
                ),
                referrer: optString(i["referrer"])
            )
            XCTAssertEqual(result, c.expected, c.name)
        }
    }

    func testTimestampFormat() {
        XCTAssertEqual(PayloadBuilder.timestamp(Date(timeIntervalSince1970: 1_763_402_645.123)), "2025-11-17T18:04:05.123Z")
        XCTAssertEqual(PayloadBuilder.timestamp(Date(timeIntervalSince1970: 0)), "1970-01-01T00:00:00.000Z")
    }

    func testBuildBody() {
        let e: JSONValue = .object(["event_id": .string("e1")])
        XCTAssertEqual(PayloadBuilder.buildBody(src: "IOS", events: [e]),
                       .object(["src": .string("IOS"), "data": .array([e])]))
    }

    func testNonStringCustomDataEntriesDropped() {
        // customData items must be {name: string, value: string} or the schema rejects the batch.
        let call = TrackCall(name: "x", data: ["customData": .array([.object(["name": .string("a"), "value": .number(1)])])],
                             properties: nil, eventId: nil)
        let event = PayloadBuilder.buildEvent(
            call: call, generatedEventId: "e", timestamp: "t", clientIdOverride: nil,
            identity: IdentitySnapshot(aid: "a", customerId: nil, adIdName: "idfa", adId: nil, custom: [:]),
            attribution: AttributionSnapshot(clickIds: [:], fbc: nil, url: nil),
            device: DeviceSnapshot(properties: [], userAgent: "ua"), referrer: nil)
        XCTAssertEqual(event["data"], .object([:]))
    }
}
