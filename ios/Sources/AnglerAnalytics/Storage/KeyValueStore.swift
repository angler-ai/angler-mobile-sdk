import Foundation

/// String key/value persistence. Only touched on `AnglerCore.queue`.
protocol KeyValueStore: AnyObject {
    func string(_ key: String) -> String?
    func set(_ value: String?, for key: String)
}

final class UserDefaultsStore: KeyValueStore {
    private let defaults: UserDefaults

    init(suiteName: String = "ai.getangler.analytics") {
        defaults = UserDefaults(suiteName: suiteName) ?? .standard
    }

    func string(_ key: String) -> String? { defaults.string(forKey: key) }

    func set(_ value: String?, for key: String) {
        if let value { defaults.set(value, forKey: key) } else { defaults.removeObject(forKey: key) }
    }
}

final class InMemoryStore: KeyValueStore {
    private var values: [String: String] = [:]
    private let lock = NSLock()

    init() {}

    func string(_ key: String) -> String? {
        lock.lock(); defer { lock.unlock() }
        return values[key]
    }

    func set(_ value: String?, for key: String) {
        lock.lock(); defer { lock.unlock() }
        values[key] = value
    }
}
