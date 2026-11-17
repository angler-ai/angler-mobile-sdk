import Foundation

protocol Clock {
    func now() -> Date
}

struct SystemClock: Clock {
    func now() -> Date { Date() }
}

extension Date {
    /// Milliseconds since 1970, rounded (so `…645.123` gives `…645123`, not `…645122`).
    var epochMillis: Int64 { Int64((timeIntervalSince1970 * 1000).rounded()) }
}
