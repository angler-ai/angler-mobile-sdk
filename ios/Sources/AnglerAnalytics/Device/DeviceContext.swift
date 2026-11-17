import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Collects device properties (design §5.2, iOS column) and the user agent.
enum DeviceContext {
    struct Screen {
        var width: Int
        var height: Int
        var scale: Double
    }

    private static let lock = NSLock()
    private static var cachedScreen: Screen?

    static func collect(wrapper: String, adTrackingEnabled: Bool, applicationTrackingEnabled: Bool) -> DeviceSnapshot {
        var props: [DeviceProperty] = []
        func add(_ name: String, _ value: String?) {
            if let value, !value.isEmpty { props.append(DeviceProperty(name: name, value: value)) }
        }
        let tz = TimeZone.current
        let model = modelIdentifier()
        let osVersion = Self.osVersion()

        #if os(iOS)
        let info = Bundle.main.infoDictionary
        add("app_package", Bundle.main.bundleIdentifier)
        add("app_version_short", info?["CFBundleShortVersionString"] as? String)
        add("app_version_long", info?["CFBundleVersion"] as? String)
        add("os", "ios")
        add("os_version", osVersion)
        add("device_model_name", model)
        add("device_timezone", tz.identifier)
        add("timezone_abbreviation", tz.abbreviation())
        add("locale", Locale.current.identifier)
        if let screen = screen() {
            add("screen_width", String(screen.width))
            add("screen_height", String(screen.height))
            add("screen_density", String(screen.scale))
        }
        add("cpu_cores", String(ProcessInfo.processInfo.activeProcessorCount))
        #else
        // macOS host (tests only): no app or hardware details.
        add("os", "ios")
        add("device_timezone", tz.identifier)
        add("timezone_abbreviation", tz.abbreviation())
        add("locale", Locale.current.identifier)
        #endif
        add("advertiser_tracking_enabled", adTrackingEnabled ? "1" : "0")
        add("application_tracking_enabled", applicationTrackingEnabled ? "1" : "0")

        let ua = userAgent(sdkVersion: SDKVersion.current, os: "iOS", osVersion: osVersion, model: model, wrapper: wrapper)
        return DeviceSnapshot(properties: props, userAgent: ua)
    }

    static func userAgent(sdkVersion: String, os: String, osVersion: String, model: String, wrapper: String) -> String {
        "AnglerAnalytics/\(sdkVersion) (\(os) \(osVersion); \(model); \(wrapper))"
    }

    /// Reads and caches the screen size. UIKit is main-thread only, so off the main thread
    /// this returns the value cached by an earlier main-thread call (`Angler.configure`).
    @discardableResult
    static func captureScreenIfOnMain() -> Screen? {
        #if canImport(UIKit) && os(iOS)
        if Thread.isMainThread {
            let screen = MainActor.assumeIsolated { () -> Screen in
                let s = UIScreen.main
                let px = s.nativeBounds.size // portrait pixels
                return Screen(width: Int(min(px.width, px.height)), height: Int(max(px.width, px.height)),
                              scale: Double(s.scale))
            }
            lock.lock(); cachedScreen = screen; lock.unlock()
            return screen
        }
        #endif
        return nil
    }

    private static func screen() -> Screen? {
        if let s = captureScreenIfOnMain() { return s }
        lock.lock(); defer { lock.unlock() }
        return cachedScreen
    }

    /// Same format as `UIDevice.systemVersion` ("17.4", "17.4.1"), without main-actor UIKit.
    private static func osVersion() -> String {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return v.patchVersion > 0 ? "\(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"
            : "\(v.majorVersion).\(v.minorVersion)"
    }

    /// `utsname.machine`, e.g. `iPhone15,2`. The simulator reports the simulated model.
    private static func modelIdentifier() -> String {
        if let sim = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"], !sim.isEmpty { return sim }
        var info = utsname()
        uname(&info)
        return withUnsafeBytes(of: &info.machine) { raw in
            String(decoding: raw.prefix { $0 != 0 }, as: UTF8.self)
        }
    }
}
