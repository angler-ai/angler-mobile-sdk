import XCTest
@testable import AnglerAnalytics

final class LifecycleTests: XCTestCase {
    func testIsNewSession() {
        XCTAssertFalse(LifecycleObserver.isNewSession(backgroundedFor: 1799))
        XCTAssertTrue(LifecycleObserver.isNewSession(backgroundedFor: 1800))
    }

    func testObserverReportsBackgroundDuration() {
        let center = NotificationCenter()
        let clock = FixedClock(date: Date(timeIntervalSince1970: 1000))
        var backgrounds = 0
        var foregrounds: [TimeInterval?] = []
        let observer = LifecycleObserver(
            clock: clock,
            notifications: LifecycleNotifications(center: center, background: .init("bg"), foreground: .init("fg")),
            onForeground: { cold, gap in XCTAssertFalse(cold); foregrounds.append(gap) },
            onBackground: { backgrounds += 1 }
        )
        center.post(name: .init("fg"), object: nil)
        center.post(name: .init("bg"), object: nil)
        clock.date = clock.date.addingTimeInterval(42)
        center.post(name: .init("fg"), object: nil)
        XCTAssertEqual(backgrounds, 1)
        XCTAssertEqual(foregrounds, [nil, 42])
        withExtendedLifetime(observer) {}
    }

    func testPrivacyManifestDeclaresUserDefaultsReason() throws {
        let url = Fixtures.repoRoot.appendingPathComponent("ios/Sources/AnglerAnalytics/Resources/PrivacyInfo.xcprivacy")
        let plist = try XCTUnwrap(PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil) as? [String: Any])
        XCTAssertEqual(plist["NSPrivacyTracking"] as? Bool, false)
        let apis = try XCTUnwrap(plist["NSPrivacyAccessedAPITypes"] as? [[String: Any]])
        XCTAssertEqual(apis.count, 1)
        XCTAssertEqual(apis[0]["NSPrivacyAccessedAPIType"] as? String, "NSPrivacyAccessedAPICategoryUserDefaults")
        XCTAssertEqual(apis[0]["NSPrivacyAccessedAPITypeReasons"] as? [String], ["CA92.1"])
        let types = try XCTUnwrap(plist["NSPrivacyCollectedDataTypes"] as? [[String: Any]]).compactMap { $0["NSPrivacyCollectedDataType"] as? String }
        XCTAssertEqual(Set(types), ["NSPrivacyCollectedDataTypeDeviceID", "NSPrivacyCollectedDataTypeProductInteraction",
                                    "NSPrivacyCollectedDataTypeOtherUsageData", "NSPrivacyCollectedDataTypeCoarseLocation"])
    }
}
