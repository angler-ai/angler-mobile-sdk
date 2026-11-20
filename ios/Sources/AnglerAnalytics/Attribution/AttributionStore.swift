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
        static let sessionURLAt = "session_url_at"
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

    /// Stores each non-empty ID with a fresh 400-day expiry and sets the session URL when `url`
    /// is non-nil. A valid `fbc` (the browser's `_fbc` cookie) becomes the `fbc` sent, and its
    /// `fbclid` is stored with it; otherwise `fbc` is derived from a new `fbclid`.
    func capture(clickIds: [String: String], url: String?) {
        let now = clock.now().epochMillis
        var entries = liveEntries(now: now)
        for (name, value) in clickIds where !value.isEmpty && name != "fbc" {
            entries[name] = Entry(value: value, capturedAtMs: now)
        }
        let linkFbc = clickIds["fbc"].flatMap { fbc in Self.fbclid(inFbc: fbc).map { (fbc: fbc, fbclid: $0) } }
        if let linkFbc { entries["fbclid"] = Entry(value: linkFbc.fbclid, capturedAtMs: now) }
        write(entries)
        if let linkFbc {
            writeFbc(FbcEntry(value: linkFbc.fbc, fbclid: linkFbc.fbclid, capturedAtMs: now))
        } else if let fbclid = clickIds["fbclid"], !fbclid.isEmpty, readFbc()?.fbclid != fbclid {
            writeFbc(FbcEntry(value: "fb.1.\(now).\(fbclid)", fbclid: fbclid, capturedAtMs: now))
        }
        if let url, !url.isEmpty {
            store.set(url, for: Key.sessionURL)
            store.set(String(now), for: Key.sessionURLAt)
        }
    }

    /// The fbclid in an `fbc` value (`fb.<subdomain index>.<creation ms>.<fbclid>`), or nil if
    /// the value isn't in that form.
    static func fbclid(inFbc fbc: String) -> String? {
        let parts = fbc.split(separator: ".", maxSplits: 3, omittingEmptySubsequences: false)
        guard parts.count == 4, parts[0] == "fb", !parts[3].isEmpty else { return nil }
        return String(parts[3])
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

    func clearSessionURL() {
        store.set(nil, for: Key.sessionURL)
        store.set(nil, for: Key.sessionURLAt)
    }

    /// Ends the session URL if it was captured at or before `cutoffMs` (the start of a long
    /// background), so a link that opened the app after that background is kept.
    func clearSessionURL(capturedAtOrBefore cutoffMs: Int64) {
        guard store.string(Key.sessionURL) != nil else { return }
        let capturedAt = store.string(Key.sessionURLAt).flatMap(Int64.init) ?? Int64.min
        if capturedAt <= cutoffMs { clearSessionURL() }
    }

    func clear() {
        store.set(nil, for: Key.clickIds)
        store.set(nil, for: Key.fbc)
        clearSessionURL()
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
