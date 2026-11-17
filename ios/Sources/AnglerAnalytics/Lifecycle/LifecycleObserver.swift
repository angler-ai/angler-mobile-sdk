import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Which notifications mean "app went to the background / came to the foreground".
struct LifecycleNotifications {
    var center: NotificationCenter
    var background: Notification.Name
    var foreground: Notification.Name

    /// UIKit's notifications on iOS; nil on the macOS test host.
    static var system: LifecycleNotifications? {
        #if canImport(UIKit) && os(iOS)
        return LifecycleNotifications(center: .default,
                                      background: UIApplication.didEnterBackgroundNotification,
                                      foreground: UIApplication.willEnterForegroundNotification)
        #else
        return nil
        #endif
    }
}

/// Foreground/background notifications → callbacks with the time spent in the background.
/// Callbacks run synchronously on the posting thread (the main thread for UIKit).
final class LifecycleObserver {
    static let sessionGap: TimeInterval = 1800

    static func isNewSession(backgroundedFor: TimeInterval) -> Bool { backgroundedFor >= sessionGap }

    private let clock: Clock
    private let onForeground: (_ coldStart: Bool, _ backgroundedFor: TimeInterval?) -> Void
    private let onBackground: () -> Void
    private let lock = NSLock()
    private var backgroundedAt: Date?
    private var tokens: [NSObjectProtocol] = []
    private let center: NotificationCenter

    init(clock: Clock,
         notifications: LifecycleNotifications,
         onForeground: @escaping (_ coldStart: Bool, _ backgroundedFor: TimeInterval?) -> Void,
         onBackground: @escaping () -> Void) {
        self.clock = clock
        self.onForeground = onForeground
        self.onBackground = onBackground
        center = notifications.center
        tokens.append(center.addObserver(forName: notifications.background, object: nil, queue: nil) { [weak self] _ in
            self?.didEnterBackground()
        })
        tokens.append(center.addObserver(forName: notifications.foreground, object: nil, queue: nil) { [weak self] _ in
            self?.willEnterForeground()
        })
    }

    deinit { tokens.forEach(center.removeObserver) }

    private func didEnterBackground() {
        lock.lock(); backgroundedAt = clock.now(); lock.unlock()
        onBackground()
    }

    /// UIKit doesn't post this notification at cold launch, so `coldStart` is always false
    /// here; `AnglerCore.configure` handles the cold start.
    private func willEnterForeground() {
        lock.lock()
        let gap = backgroundedAt.map { clock.now().timeIntervalSince($0) }
        backgroundedAt = nil
        lock.unlock()
        onForeground(false, gap)
    }
}
