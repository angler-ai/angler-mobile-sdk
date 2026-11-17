import Foundation

/// Batches queued events, sends them, and applies the response policy and backoff
/// (design §7). Every call, and every transport callback, must happen on the owner's
/// serial queue; `AnglerCore` wraps its transport so callbacks hop back onto it.
final class Flusher {
    private let queue: EventQueue
    private let transport: Transport
    private let src: String
    private let batchSize: Int
    private let scheduler: Scheduler
    private let random: () -> Double

    private(set) var isPaused = false
    /// True while a request is in flight or a retry is waiting.
    private(set) var isFlushing = false
    private var attempt = 0
    private var waitingForRetry = false
    private var completions: [() -> Void] = []
    /// Event groups still to send in this cycle (after isolate or split), last = next.
    private var pendingGroups: [[QueuedEvent]] = []

    init(queue: EventQueue, transport: Transport, src: String, batchSize: Int,
         scheduler: Scheduler, random: @escaping () -> Double) {
        self.queue = queue
        self.transport = transport
        self.src = src
        self.batchSize = max(1, batchSize)
        self.scheduler = scheduler
        self.random = random
    }

    /// Starts a flush unless one is already running (single flight) or the flusher is
    /// paused. `completion` runs when the current cycle ends: the queue is drained,
    /// sending is paused, or a retry has been scheduled.
    func flush(completion: (() -> Void)?) {
        if let completion { completions.append(completion) }
        guard !isPaused else { return finish() }
        guard !isFlushing else {
            if waitingForRetry { runCompletions() }
            return
        }
        isFlushing = true
        sendNext()
    }

    private func sendNext() {
        let group: [QueuedEvent]
        if let next = pendingGroups.popLast() {
            group = next
        } else {
            group = queue.peek(batchSize)
        }
        guard !group.isEmpty else { return finish() }

        let body = PayloadBuilder.buildBody(src: src, events: group.map(\.body)).encoded()
        transport.send(body) { [weak self] status in
            self?.handle(status: status, group: group)
        }
    }

    private func handle(status: Int?, group: [QueuedEvent]) {
        let decision = ResponsePolicy.decide(status: status, batchSize: group.count)
        switch decision {
        case .remove:
            attempt = 0
            queue.remove(seqs: Set(group.map(\.seq)))
            Log.debug("delivered \(group.count) event(s)")
        case .drop:
            attempt = 0
            queue.remove(seqs: Set(group.map(\.seq)))
            Log.error("dropping \(group.count) event(s) rejected with HTTP \(status.map(String.init) ?? "-")")
        case .isolate:
            pendingGroups.append(contentsOf: group.reversed().map { [$0] })
        case .split:
            let mid = group.count / 2
            pendingGroups.append(Array(group[mid...]))
            pendingGroups.append(Array(group[..<mid]))
        case .pause:
            isPaused = true
            pendingGroups.removeAll()
            Log.error("HTTP \(status.map(String.init) ?? "-"): check the workspace token; sending paused until next launch")
            return finish()
        case .retry:
            pendingGroups.removeAll()
            attempt += 1
            let delay = Backoff.delay(attempt: attempt, r: random())
            Log.debug("send failed (\(status.map(String.init) ?? "network error")); retrying in \(delay)s")
            waitingForRetry = true
            scheduler.schedule(after: delay) { [weak self] in
                guard let self else { return }
                self.waitingForRetry = false
                self.isPaused ? self.finish() : self.sendNext()
            }
            // The attempt is over: release callers (e.g. a background task) while the
            // retry waits. isFlushing stays true so no second cycle starts meanwhile.
            return runCompletions()
        }
        sendNext()
    }

    private func finish() {
        isFlushing = false
        runCompletions()
    }

    private func runCompletions() {
        let done = completions
        completions.removeAll()
        done.forEach { $0() }
    }
}
