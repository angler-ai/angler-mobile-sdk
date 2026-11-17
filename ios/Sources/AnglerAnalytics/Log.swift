import Foundation
import os

/// SDK logging. Debug messages only print when `debugLogging` is on; warnings and errors
/// always go to the unified log.
enum Log {
    private static let logger = os.Logger(subsystem: "ai.getangler.analytics", category: "Angler")
    private static let lock = NSLock()
    private static var _debugEnabled = false

    static var debugEnabled: Bool {
        get { lock.lock(); defer { lock.unlock() }; return _debugEnabled }
        set { lock.lock(); _debugEnabled = newValue; lock.unlock() }
    }

    static func debug(_ message: @autoclosure () -> String) {
        guard debugEnabled else { return }
        let m = message()
        logger.debug("\(m, privacy: .public)")
    }

    static func warning(_ message: String) { logger.warning("\(message, privacy: .public)") }
    static func error(_ message: String) { logger.error("\(message, privacy: .public)") }
}
