import Foundation

struct AttributionSnapshot: Equatable {
    var clickIds: [String: String]
    var fbc: String?
    var url: String?
}

/// Persists click IDs, `fbc` and the session URL (design §6.2, §6.3).
final class AttributionStore {
    static let clickIdTTLMillis: Int64 = 400 * 86_400 * 1000

    private enum Key {
        static let clickIds = "click_ids"
        static let fbc = "fbc"
        static let sessionURL = "session_url"
    }

    private struct Entry: Codable {
        var value: String
        var capturedAtMs: Int64
    }

    private struct FbcEntry: Codable {
        var value: String
        var fbclid: String
        var capturedAtMs: Int64
    }

    private let store: KeyValueStore
    private let clock: Clock

    init(store: KeyValueStore, clock: Clock) {
        self.store = store
        self.clock = clock
    }

    /// Stores each non-empty click ID with a fresh 400-day expiry, derives `fbc` from
    /// `fbclid`, and sets the session URL when `url` is non-nil.
    func capture(clickIds: [String: String], url: String?) {
        let now = clock.now().epochMillis
        var entries = liveEntries(now: now)
        for (name, value) in clickIds where !value.isEmpty {
            entries[name] = Entry(value: value, capturedAtMs: now)
        }
        write(entries)
        if let fbclid = clickIds["fbclid"], !fbclid.isEmpty, readFbc()?.fbclid != fbclid {
            writeFbc(FbcEntry(value: "fb.1.\(now).\(fbclid)", fbclid: fbclid, capturedAtMs: now))
        }
        if let url, !url.isEmpty { store.set(url, for: Key.sessionURL) }
    }

    func snapshot() -> AttributionSnapshot {
        let entries = liveEntries(now: clock.now().epochMillis)
        var fbc: String?
        if let f = readFbc(), entries["fbclid"]?.value == f.fbclid { fbc = f.value }
        return AttributionSnapshot(
            clickIds: entries.mapValues(\.value),
            fbc: fbc,
            url: store.string(Key.sessionURL)
        )
    }

    func clearSessionURL() { store.set(nil, for: Key.sessionURL) }

    func clear() {
        store.set(nil, for: Key.clickIds)
        store.set(nil, for: Key.fbc)
        store.set(nil, for: Key.sessionURL)
    }

    private func liveEntries(now: Int64) -> [String: Entry] {
        guard let raw = store.string(Key.clickIds),
              let all = try? JSONDecoder().decode([String: Entry].self, from: Data(raw.utf8))
        else { return [:] }
        return all.filter { now - $0.value.capturedAtMs < Self.clickIdTTLMillis }
    }

    private func write(_ entries: [String: Entry]) {
        if entries.isEmpty { store.set(nil, for: Key.clickIds); return }
        let data = (try? JSONEncoder().encode(entries)) ?? Data("{}".utf8)
        store.set(String(decoding: data, as: UTF8.self), for: Key.clickIds)
    }

    private func readFbc() -> FbcEntry? {
        guard let raw = store.string(Key.fbc) else { return nil }
        return try? JSONDecoder().decode(FbcEntry.self, from: Data(raw.utf8))
    }

    private func writeFbc(_ entry: FbcEntry) {
        let data = (try? JSONEncoder().encode(entry)) ?? Data()
        store.set(String(decoding: data, as: UTF8.self), for: Key.fbc)
    }
}
