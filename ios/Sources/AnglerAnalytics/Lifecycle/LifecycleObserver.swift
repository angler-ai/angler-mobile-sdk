import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Which notifications mean "app went to the background / became active".
struct LifecycleNotifications {
    var center: NotificationCenter
    var background: Notification.Name
    var foreground: Notification.Name
    /// Whether the app is in the foreground right now. Called on the main thread at configure,
    /// because wrappers (React Native, Flutter) configure after the app is already active.
    var isActive: (() -> Bool)? = nil

    /// UIKit's notifications on iOS; nil on the macOS test host.
    static var system: LifecycleNotifications? {
        #if canImport(UIKit) && os(iOS)
        return LifecycleNotifications(
            center: .default,
            background: UIApplication.didEnterBackgroundNotification,
            // didBecomeActive (not willEnterForeground): it also fires on a cold start, and after
            // a URL that opened the app has been delivered.
            foreground: UIApplication.didBecomeActiveNotification,
            isActive: {
                Thread.isMainThread && MainActor.assumeIsolated { UIApplication.shared.applicationState == .active }
            }
        )
        #else
        return nil
        #endif
    }
}

/// Foreground/background notifications → callbacks, run synchronously on the posting thread
/// (the main thread for UIKit). Session timing lives in `AnglerCore`, which persists it.
final class LifecycleObserver {
    static let sessionGap: TimeInterval = 1800

    static func isNewSession(backgroundedFor: TimeInterval) -> Bool { backgroundedFor >= sessionGap }

    private var tokens: [NSObjectProtocol] = []
    private let center: NotificationCenter

    init(notifications: LifecycleNotifications, onForeground: @escaping () -> Void, onBackground: @escaping () -> Void) {
        center = notifications.center
        tokens.append(center.addObserver(forName: notifications.background, object: nil, queue: nil) { _ in onBackground() })
        tokens.append(center.addObserver(forName: notifications.foreground, object: nil, queue: nil) { _ in onForeground() })
    }

    deinit { tokens.forEach(center.removeObserver) }
}
