import Foundation

protocol FirebaseIdProviding {
    /// Firebase Analytics' app instance ID, or nil when the app doesn't use Firebase Analytics.
    func appInstanceId() -> String?
}

struct NoFirebaseIdProvider: FirebaseIdProviding {
    func appInstanceId() -> String? { nil }
}

/// Reads `Analytics.appInstanceID()` when the host app links Firebase Analytics, without the SDK
/// depending on Firebase: the classes are looked up at runtime. Nil until the app has called
/// `FirebaseApp.configure()`, and nil while analytics storage consent is denied. A found ID is
/// cached for the process.
final class SystemFirebaseIdProvider: FirebaseIdProviding {
    private let lock = NSLock()
    private var cached: String?

    func appInstanceId() -> String? {
        lock.lock()
        defer { lock.unlock() }
        if let cached { return cached }
        guard let app = NSClassFromString("FIRApp") as AnyObject?,
              app.responds(to: NSSelectorFromString("defaultApp")),
              app.perform(NSSelectorFromString("defaultApp"))?.takeUnretainedValue() != nil,
              let analytics = NSClassFromString("FIRAnalytics") as AnyObject?,
              analytics.responds(to: NSSelectorFromString("appInstanceID")),
              let id = analytics.perform(NSSelectorFromString("appInstanceID"))?.takeUnretainedValue() as? String,
              !id.isEmpty
        else { return nil }
        cached = id
        return id
    }
}
