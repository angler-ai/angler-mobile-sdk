import Foundation

protocol Scheduler {
    func schedule(after: TimeInterval, _ work: @escaping () -> Void)
}

struct DispatchScheduler: Scheduler {
    let queue: DispatchQueue

    func schedule(after delay: TimeInterval, _ work: @escaping () -> Void) {
        queue.asyncAfter(deadline: .now() + delay, execute: work)
    }
}
