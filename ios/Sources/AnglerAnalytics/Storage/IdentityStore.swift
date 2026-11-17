import Foundation

/// The install ID (`aid`), the user ID, custom identifiers and the stored flags.
final class IdentityStore {
    private enum Key {
        static let aid = "aid"
        static let customerId = "customer_id"
        static let custom = "custom_identifiers"
        static let enabled = "enabled"
        static let appTracking = "application_tracking_enabled"
    }

    /// Names a custom identifier may never use.
    static let reservedNames: Set<String> =
        Set(["aid", "customer_id", "idfa", "gaid"]).union(ClickIdParser.identifierByParameter.values)

    private let store: KeyValueStore

    init(store: KeyValueStore) { self.store = store }

    /// Returns the stored `aid`, creating one if none exists. `isNew` means a first launch.
    func ensureAid() -> (aid: String, isNew: Bool) {
        if let aid = store.string(Key.aid), !aid.isEmpty { return (aid, false) }
        let aid = Self.newAid()
        store.set(aid, for: Key.aid)
        return (aid, true)
    }

    var customerId: String? {
        get { store.string(Key.customerId) }
        set { store.set(newValue, for: Key.customerId) }
    }

    /// Sets or (with nil) removes a custom identifier. Returns false for a reserved name.
    @discardableResult
    func setIdentifier(_ name: String, value: String?) -> Bool {
        guard !name.isEmpty, !Self.reservedNames.contains(name) else { return false }
        var ids = customIdentifiers
        ids[name] = value
        writeCustom(ids)
        return true
    }

    var customIdentifiers: [String: String] {
        guard let raw = store.string(Key.custom),
              let ids = try? JSONDecoder().decode([String: String].self, from: Data(raw.utf8))
        else { return [:] }
        return ids
    }

    var isEnabled: Bool {
        get { store.string(Key.enabled) != "0" }
        set { store.set(newValue ? "1" : "0", for: Key.enabled) }
    }

    var applicationTrackingEnabled: Bool {
        get { store.string(Key.appTracking) != "0" }
        set { store.set(newValue ? "1" : "0", for: Key.appTracking) }
    }

    /// Clears the user ID and custom identifiers and rotates the `aid`.
    func reset() {
        store.set(nil, for: Key.customerId)
        store.set(nil, for: Key.custom)
        store.set(Self.newAid(), for: Key.aid)
    }

    private func writeCustom(_ ids: [String: String]) {
        if ids.isEmpty { store.set(nil, for: Key.custom); return }
        let data = (try? JSONEncoder().encode(ids)) ?? Data("{}".utf8)
        store.set(String(decoding: data, as: UTF8.self), for: Key.custom)
    }

    private static func newAid() -> String { UUID().uuidString.lowercased() }
}
