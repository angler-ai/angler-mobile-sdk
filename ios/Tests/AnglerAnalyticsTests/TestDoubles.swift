import Foundation
@testable import AnglerAnalytics

/// A clock tests move by hand. A class, so the stores that hold it see the change.
final class FixedClock: Clock {
    var date: Date
    init(date: Date) { self.date = date }
    func now() -> Date { date }
}
