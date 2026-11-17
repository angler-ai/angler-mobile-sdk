import XCTest
@testable import AnglerAnalytics

final class FlusherTests: XCTestCase {
    private var dir: URL!
    private var queue: EventQueue!
    private var transport: FakeTransport!
    private var scheduler: ManualScheduler!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        queue = EventQueue(fileURL: dir.appendingPathComponent("q.json"), maxSize: 1000)
        transport = FakeTransport()
        scheduler = ManualScheduler()
    }

    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: dir) }

    private func makeFlusher(r: Double = 0.5) -> Flusher {
        Flusher(queue: queue, transport: transport, src: "IOS", batchSize: 100, scheduler: scheduler, random: { r })
    }

    private func enqueue(_ n: Int, prefix: String = "e") {
        for i in 0..<n { queue.append(.object(["event_id": .string("\(prefix)\(i)")])) }
    }

    func testBatchesOf100() {
        enqueue(250)
        makeFlusher().flush(completion: nil)
        XCTAssertEqual(transport.batchSizes(), [100, 100, 50])
        XCTAssertEqual(queue.count, 0)
    }

    func testIsolateDeliversGoodEvents() {
        enqueue(3)
        transport.responses = [400, 201, 400, 201]
        makeFlusher().flush(completion: nil)
        XCTAssertEqual(queue.count, 0)
        XCTAssertEqual(transport.requestCount, 4)
        XCTAssertEqual(transport.batchSizes(), [3, 1, 1, 1])
        let delivered = [transport.bodies[1], transport.bodies[3]].compactMap { $0["data"]?.arrayValue?.first?["event_id"]?.stringValue }
        XCTAssertEqual(delivered, ["e0", "e2"])
    }

    func testOneBadEventInBatchOf100() {
        enqueue(100)
        transport.responder = { body in
            let ids = body["data"]!.arrayValue!.map { $0["event_id"]!.stringValue! }
            return ids.contains("e42") ? 400 : 201
        }
        makeFlusher().flush(completion: nil)
        XCTAssertEqual(queue.count, 0)
        XCTAssertEqual(transport.requestCount, 101)
        XCTAssertEqual(Set(transport.bodies.dropFirst().compactMap { $0["data"]?.arrayValue?.first?["event_id"]?.stringValue }).count, 100)
    }

    func testSplitOn413() {
        enqueue(4)
        transport.responses = [413, 201, 201]
        makeFlusher().flush(completion: nil)
        XCTAssertEqual(transport.batchSizes(), [4, 2, 2])
        XCTAssertEqual(queue.count, 0)
    }

    func testRetryKeepsEventsAndSchedulesBackoff() {
        enqueue(2)
        transport.responses = [503]
        let flusher = makeFlusher(r: 0.5)
        flusher.flush(completion: nil)
        XCTAssertEqual(queue.count, 2)
        XCTAssertEqual(scheduler.delays.count, 1)
        XCTAssertGreaterThanOrEqual(scheduler.delays[0], 0.5)
        XCTAssertLessThanOrEqual(scheduler.delays[0], 1.0)
        scheduler.advance(by: 1.0)
        XCTAssertEqual(queue.count, 0)
        XCTAssertEqual(transport.requestCount, 2)
    }

    func testBackoffGrowsAndResetsAfterSuccess() {
        enqueue(1)
        transport.responses = [nil, nil, 201]
        let flusher = makeFlusher(r: 0)
        flusher.flush(completion: nil)
        scheduler.advance(by: 0.5)
        scheduler.advance(by: 1.0)
        XCTAssertEqual(scheduler.delays, [0.5, 1.0])
        XCTAssertEqual(queue.count, 0)
        enqueue(1)
        transport.responses = [500]
        flusher.flush(completion: nil)
        XCTAssertEqual(scheduler.delays.last, 0.5)
    }

    func testPauseOn401StopsFlushing() {
        enqueue(2)
        transport.responses = [401]
        let flusher = makeFlusher()
        flusher.flush(completion: nil)
        XCTAssertTrue(flusher.isPaused)
        XCTAssertEqual(queue.count, 2)
        flusher.flush(completion: nil)
        scheduler.advance(by: 1000)
        XCTAssertEqual(transport.requestCount, 1)
    }

    func testSingleFlight() {
        enqueue(2)
        transport.autoRespond = false
        let flusher = makeFlusher()
        flusher.flush(completion: nil)
        XCTAssertTrue(flusher.isFlushing)
        flusher.flush(completion: nil)
        flusher.flush(completion: nil)
        XCTAssertEqual(transport.requestCount, 1)
        var done = 0
        flusher.flush { done += 1 }
        transport.pending.removeFirst()(201)
        XCTAssertFalse(flusher.isFlushing)
        XCTAssertEqual(done, 1)
        XCTAssertEqual(queue.count, 0)
    }

    func testEventsAppendedDuringFlushAreKept() {
        enqueue(2)
        transport.autoRespond = false
        let flusher = makeFlusher()
        flusher.flush(completion: nil)
        enqueue(1, prefix: "late")
        transport.pending.removeFirst()(201)
        // The late event was not in the first batch; it is sent next, not lost.
        XCTAssertEqual(transport.requestCount, 2)
        XCTAssertEqual(transport.bodies[1]["data"]?.arrayValue?.first?["event_id"], .string("late0"))
        transport.pending.removeFirst()(201)
        XCTAssertEqual(queue.count, 0)
    }

    func testRequestBodyShape() {
        enqueue(1)
        makeFlusher().flush(completion: nil)
        XCTAssertEqual(transport.bodies[0], .object(["src": .string("IOS"), "data": .array([.object(["event_id": .string("e0")])])]))
    }

    func testCompletionCalledWhenQueueEmpty() {
        var done = false
        makeFlusher().flush { done = true }
        XCTAssertTrue(done)
        XCTAssertEqual(transport.requestCount, 0)
    }

    func testCompletionCalledWhenRetryScheduled() {
        enqueue(1)
        transport.responses = [503]
        let flusher = makeFlusher()
        var done = false
        flusher.flush { done = true }
        XCTAssertTrue(done, "a waiting retry must not hold callers (e.g. a background task)")
        XCTAssertTrue(flusher.isFlushing)
        var second = false
        flusher.flush { second = true }
        XCTAssertTrue(second)
        XCTAssertEqual(transport.requestCount, 1, "no extra request while the retry waits")
    }
}

final class EndpointTests: XCTestCase {
    func testEndpointNormalizesDomain() {
        for domain in ["dev-data.getangler.ai", "https://dev-data.getangler.ai/", " HTTPS://dev-data.getangler.ai "] {
            XCTAssertEqual(URLSessionTransport.endpoint(domain: domain, workspaceId: "ws")?.absoluteString,
                           "https://dev-data.getangler.ai/v1/workspaces/ws/events", domain)
        }
        XCTAssertEqual(URLSessionTransport.endpoint(domain: "localhost:8443", workspaceId: "ws")?.absoluteString,
                       "https://localhost:8443/v1/workspaces/ws/events")
    }

    func testInvalidDomainHasNoEndpoint() {
        for domain in ["", "https://", "has space.ai", "data.getangler.ai/path", "http://x.ai?q=1"] {
            XCTAssertNil(URLSessionTransport.endpoint(domain: domain, workspaceId: "ws"), domain)
        }
    }
}
