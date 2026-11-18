import Foundation
@testable import AnglerAnalytics

/// A clock tests move by hand. A class, so the stores that hold it see the change.
final class FixedClock: Clock {
    var date: Date
    init(date: Date) { self.date = date }
    func now() -> Date { date }
}

/// Records request bodies. With `autoRespond`, answers synchronously from `responses`
/// (then `defaultStatus`); otherwise completions wait in `pending` for the test.
final class FakeTransport: Transport {
    var autoRespond = true
    var responses: [Int?] = []
    var defaultStatus: Int? = 201
    /// When set, every response is computed from the request body.
    var responder: ((JSONValue) -> Int?)?
    private(set) var bodies: [JSONValue] = []
    var pending: [(Int?) -> Void] = []
    private let lock = NSLock()

    func send(_ body: Data, completion: @escaping (Int?) -> Void) {
        let decoded = try! JSONDecoder().decode(JSONValue.self, from: body)
        lock.lock()
        bodies.append(decoded)
        let status: Int?
        if let responder { status = responder(decoded) }
        else if !responses.isEmpty { status = responses.removeFirst() }
        else { status = defaultStatus }
        let auto = autoRespond
        if !auto { pending.append(completion) }
        lock.unlock()
        if auto { completion(status) }
    }

    var requestCount: Int { lock.lock(); defer { lock.unlock() }; return bodies.count }

    func batchSizes() -> [Int] {
        lock.lock(); defer { lock.unlock() }
        return bodies.map { $0["data"]?.arrayValue?.count ?? 0 }
    }

    func deliveredEventIds() -> [String] {
        lock.lock(); defer { lock.unlock() }
        return bodies.flatMap { $0["data"]?.arrayValue ?? [] }.compactMap { $0["event_id"]?.stringValue }
    }
}

/// Runs scheduled work only when the test advances time.
final class ManualScheduler: Scheduler {
    private(set) var now: TimeInterval = 0
    private(set) var items: [(at: TimeInterval, work: () -> Void)] = []
    var delays: [TimeInterval] = []

    func schedule(after delay: TimeInterval, _ work: @escaping () -> Void) {
        delays.append(delay)
        items.append((now + delay, work))
    }

    func advance(by seconds: TimeInterval) {
        let target = now + seconds
        while let idx = items.indices.filter({ items[$0].at <= target }).min(by: { items[$0].at < items[$1].at }) {
            let item = items.remove(at: idx)
            now = item.at
            item.work()
        }
        now = target
    }
}
