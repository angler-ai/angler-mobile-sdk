import Foundation

enum FlushDecision: String {
    case remove, isolate, drop, split, pause, retry
}

/// HTTP result → what to do with the batch (design §7.2). Pure.
enum ResponsePolicy {
    /// `status` nil means a network error or timeout.
    static func decide(status: Int?, batchSize: Int) -> FlushDecision {
        guard let status else { return .retry }
        switch status {
        case 200..<300: return .remove
        case 400: return batchSize > 1 ? .isolate : .drop
        case 413: return batchSize > 1 ? .split : .drop
        case 401, 403: return .pause
        case 429, 500..<600: return .retry
        default: return .drop
        }
    }
}

enum Backoff {
    /// `min(300, 2^(attempt-1)) × (0.5 + 0.5·r)` seconds, `r` in [0, 1).
    static func delay(attempt: Int, r: Double) -> TimeInterval {
        let base = min(300, pow(2, Double(max(1, attempt) - 1)))
        return base * (0.5 + 0.5 * r)
    }
}
