import Foundation

/// A JSON value. Events are built as `JSONValue` at `track()` time and stored in the
/// queue exactly as they will be sent.
enum JSONValue: Codable, Equatable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case null
    case array([JSONValue])
    case object([String: JSONValue])

    /// Converts a Foundation value. Returns nil for values JSON can't represent;
    /// such values are dropped from inside arrays and objects.
    static func from(_ any: Any) -> JSONValue? {
        switch any {
        case let v as JSONValue:
            return v
        case let s as String:
            return .string(s)
        case let n as NSNumber:
            if CFGetTypeID(n) == CFBooleanGetTypeID() { return .bool(n.boolValue) }
            let d = n.doubleValue
            return d.isFinite ? .number(d) : nil
        case is NSNull:
            return .null
        case let a as [Any]:
            return .array(a.compactMap { from($0) })
        case let o as [String: Any]:
            var out: [String: JSONValue] = [:]
            for (k, v) in o { if let j = from(v) { out[k] = j } }
            return .object(out)
        default:
            // Optional.none boxed in Any
            if case Optional<Any>.none = any { return .null }
            return nil
        }
    }

    /// Compact JSON with sorted keys.
    func encoded() -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return (try? encoder.encode(self)) ?? Data("null".utf8)
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let b = try? c.decode(Bool.self) { self = .bool(b) }
        else if let d = try? c.decode(Double.self) { self = .number(d) }
        else if let s = try? c.decode(String.self) { self = .string(s) }
        else if let a = try? c.decode([JSONValue].self) { self = .array(a) }
        else { self = .object(try c.decode([String: JSONValue].self)) }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let s): try c.encode(s)
        case .number(let d):
            if d.rounded() == d, abs(d) < 1e15 { try c.encode(Int64(d)) } else { try c.encode(d) }
        case .bool(let b): try c.encode(b)
        case .null: try c.encodeNil()
        case .array(let a): try c.encode(a)
        case .object(let o): try c.encode(o)
        }
    }

    var stringValue: String? { if case .string(let s) = self { return s }; return nil }
    var objectValue: [String: JSONValue]? { if case .object(let o) = self { return o }; return nil }
    var arrayValue: [JSONValue]? { if case .array(let a) = self { return a }; return nil }
    subscript(key: String) -> JSONValue? { objectValue?[key] }
}
