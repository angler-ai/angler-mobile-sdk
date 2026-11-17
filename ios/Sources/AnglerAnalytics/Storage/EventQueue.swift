import Foundation

struct QueuedEvent: Codable, Equatable {
    /// Increases steadily and is never reused, even across reloads.
    var seq: Int64
    /// The finished event JSON, sent exactly as stored.
    var body: JSONValue
}

/// Disk-backed FIFO of finished events (design §7.1). Not thread-safe on its own:
/// `AnglerCore.queue` serializes every call.
final class EventQueue {
    private struct FileContents: Codable {
        var nextSeq: Int64
        var events: [QueuedEvent]
    }

    private let fileURL: URL
    private let maxSize: Int
    private var events: [QueuedEvent] = []
    private var nextSeq: Int64 = 1

    init(fileURL: URL, maxSize: Int) {
        self.fileURL = fileURL
        self.maxSize = max(1, maxSize)
        load()
    }

    var count: Int { events.count }

    /// Appends an event; when full, the oldest events are dropped.
    func append(_ body: JSONValue) {
        events.append(QueuedEvent(seq: nextSeq, body: body))
        nextSeq += 1
        if events.count > maxSize {
            let dropped = events.count - maxSize
            events.removeFirst(dropped)
            Log.debug("queue full: dropped \(dropped) oldest event(s)")
        }
        save()
    }

    func peek(_ n: Int) -> [QueuedEvent] { Array(events.prefix(max(0, n))) }

    func remove(seqs: Set<Int64>) {
        guard !seqs.isEmpty else { return }
        let before = events.count
        events.removeAll { seqs.contains($0.seq) }
        if events.count != before { save() }
    }

    func removeAll() {
        events.removeAll()
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        guard let contents = try? JSONDecoder().decode(FileContents.self, from: data) else {
            Log.warning("queue file unreadable; starting empty")
            try? FileManager.default.removeItem(at: fileURL)
            return
        }
        events = Array(contents.events.suffix(maxSize))
        nextSeq = max(contents.nextSeq, (events.last?.seq ?? 0) + 1)
    }

    /// Atomic write (temp file, then rename).
    private func save() {
        let dir = fileURL.deletingLastPathComponent()
        do {
            if !FileManager.default.fileExists(atPath: dir.path) {
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                var values = URLResourceValues()
                values.isExcludedFromBackup = true
                var mutableDir = dir
                try? mutableDir.setResourceValues(values)
            }
            let data = try JSONEncoder().encode(FileContents(nextSeq: nextSeq, events: events))
            try data.write(to: fileURL, options: .atomic)
        } catch {
            Log.error("could not write queue file: \(error.localizedDescription)")
        }
    }
}
