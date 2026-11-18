import XCTest
@testable import AnglerAnalytics

final class EventQueueTests: XCTestCase {
    private var dir: URL!
    private var file: URL { dir.appendingPathComponent("AnglerAnalytics/queue-ws.json") }

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    private func ev(_ id: String) -> JSONValue { .object(["event_id": .string(id)]) }

    func testPersistsAcrossInstances() {
        let q = EventQueue(fileURL: file, maxSize: 10)
        ["e1", "e2", "e3"].forEach { q.append(ev($0)) }
        let reloaded = EventQueue(fileURL: file, maxSize: 10)
        XCTAssertEqual(reloaded.peek(10).map(\.body), [ev("e1"), ev("e2"), ev("e3")])
        XCTAssertEqual(reloaded.count, 3)
    }

    func testDropsOldestWhenFull() {
        let q = EventQueue(fileURL: file, maxSize: 3)
        ["e1", "e2", "e3", "e4", "e5"].forEach { q.append(ev($0)) }
        XCTAssertEqual(q.peek(10).map(\.body), [ev("e3"), ev("e4"), ev("e5")])
        XCTAssertEqual(EventQueue(fileURL: file, maxSize: 3).peek(10).map(\.body), [ev("e3"), ev("e4"), ev("e5")])
    }

    func testRemoveBySeqKeepsOthers() {
        let q = EventQueue(fileURL: file, maxSize: 10)
        ["e1", "e2", "e3"].forEach { q.append(ev($0)) }
        let middle = q.peek(10)[1].seq
        q.remove(seqs: [middle])
        XCTAssertEqual(q.peek(10).map(\.body), [ev("e1"), ev("e3")])
        XCTAssertEqual(EventQueue(fileURL: file, maxSize: 10).peek(10).map(\.body), [ev("e1"), ev("e3")])
    }

    func testRemoveAll() {
        let q = EventQueue(fileURL: file, maxSize: 10)
        q.append(ev("e1"))
        q.removeAll()
        XCTAssertEqual(q.count, 0)
        XCTAssertEqual(EventQueue(fileURL: file, maxSize: 10).count, 0)
    }

    func testCorruptFileStartsEmpty() throws {
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: file)
        let q = EventQueue(fileURL: file, maxSize: 10)
        XCTAssertEqual(q.count, 0)
        q.append(ev("e1"))
        XCTAssertEqual(EventQueue(fileURL: file, maxSize: 10).peek(10).map(\.body), [ev("e1")])
    }

    func testSeqUniqueWithDuplicateEventIds() {
        let q = EventQueue(fileURL: file, maxSize: 10)
        q.append(ev("same"))
        q.append(ev("same"))
        let seqs = q.peek(10).map(\.seq)
        XCTAssertEqual(Set(seqs).count, 2)
    }

    func testSeqNeverReusedAfterRemovalAndReload() {
        let q = EventQueue(fileURL: file, maxSize: 10)
        q.append(ev("e1"))
        let first = q.peek(1)[0].seq
        q.remove(seqs: [first])
        let reloaded = EventQueue(fileURL: file, maxSize: 10)
        reloaded.append(ev("e2"))
        XCTAssertGreaterThan(reloaded.peek(1)[0].seq, first)
    }

    func testDirectoryExcludedFromBackup() throws {
        EventQueue(fileURL: file, maxSize: 10).append(ev("e1"))
        let values = try file.deletingLastPathComponent().resourceValues(forKeys: [.isExcludedFromBackupKey])
        XCTAssertEqual(values.isExcludedFromBackup, true)
    }
}
