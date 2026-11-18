import XCTest
@testable import AnglerAnalytics

final class DeviceContextTests: XCTestCase {
    private func props(_ s: DeviceSnapshot) -> [String: String] {
        Dictionary(s.properties.map { ($0.name, $0.value) }, uniquingKeysWith: { a, _ in a })
    }

    func testUserAgent() {
        XCTAssertEqual(
            DeviceContext.userAgent(sdkVersion: "1.0.0", os: "iOS", osVersion: "17.4", model: "iPhone15,2", wrapper: "native"),
            "AnglerAnalytics/1.0.0 (iOS 17.4; iPhone15,2; native)"
        )
    }

    func testCollectOnlyAllowedNames() {
        let s = DeviceContext.collect(wrapper: "native", adTrackingEnabled: false, applicationTrackingEnabled: true)
        let names = s.properties.map(\.name)
        XCTAssertEqual(Set(names).count, names.count, "no duplicate names")
        for n in names { XCTAssertTrue(PayloadBuilder.allowedDeviceProperties.contains(n), n) }
        for n in ["ext_storage_in_gb", "free_ext_storage_in_gb", "carrier", "app_id"] {
            XCTAssertFalse(names.contains(n), n)
        }
        XCTAssertTrue(s.properties.allSatisfy { !$0.value.isEmpty })
    }

    func testTrackingFlags() {
        let off = props(DeviceContext.collect(wrapper: "native", adTrackingEnabled: false, applicationTrackingEnabled: false))
        XCTAssertEqual(off["advertiser_tracking_enabled"], "0")
        XCTAssertEqual(off["application_tracking_enabled"], "0")
        let on = props(DeviceContext.collect(wrapper: "native", adTrackingEnabled: true, applicationTrackingEnabled: true))
        XCTAssertEqual(on["advertiser_tracking_enabled"], "1")
        XCTAssertEqual(on["application_tracking_enabled"], "1")
    }

    func testOsAndUserAgentWrapper() {
        let s = DeviceContext.collect(wrapper: "flutter", adTrackingEnabled: false, applicationTrackingEnabled: true)
        XCTAssertEqual(props(s)["os"], "ios")
        XCTAssertTrue(s.userAgent.hasPrefix("AnglerAnalytics/\(SDKVersion.current) (iOS "), s.userAgent)
        XCTAssertTrue(s.userAgent.hasSuffix("; flutter)"), s.userAgent)
        XCTAssertNotNil(props(s)["device_timezone"])
        XCTAssertNotNil(props(s)["locale"])
    }

    #if os(iOS)
    func testScreenOnDevice() throws {
        let p = props(DeviceContext.collect(wrapper: "native", adTrackingEnabled: false, applicationTrackingEnabled: true))
        let w = try XCTUnwrap(Int(p["screen_width"] ?? ""))
        let h = try XCTUnwrap(Int(p["screen_height"] ?? ""))
        XCTAssertGreaterThan(w, 0)
        XCTAssertLessThanOrEqual(w, h)
        XCTAssertNotNil(Double(p["screen_density"] ?? ""))
        XCTAssertNotNil(Int(p["cpu_cores"] ?? ""))
        XCTAssertNotNil(p["os_version"])
        XCTAssertNotNil(p["device_model_name"])
    }
    #endif

    func testAppStoreIdIsNormalizedToAppsFlyerForm() {
        XCTAssertEqual(DeviceContext.normalizeAppStoreId("1234567890"), "id1234567890")
        XCTAssertEqual(DeviceContext.normalizeAppStoreId(" id1234567890 "), "id1234567890")
        XCTAssertNil(DeviceContext.normalizeAppStoreId(""))
        XCTAssertNil(DeviceContext.normalizeAppStoreId(nil))
    }
}
