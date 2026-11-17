import Foundation
@testable import AnglerAnalytics

/// Loads the shared cross-platform cases from `<repo>/spec/fixtures/<file>.json`.
enum Fixtures {
    struct Missing: Error {}

    static var repoRoot: URL {
        // <repo>/ios/Tests/AnglerAnalyticsTests/Fixtures.swift
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
    }

    static func load(_ file: String) throws -> [(name: String, input: JSONValue, expected: JSONValue)] {
        let url = repoRoot.appendingPathComponent("spec/fixtures/\(file).json")
        let root = try JSONDecoder().decode(JSONValue.self, from: Data(contentsOf: url))
        guard case .object(let obj) = root, case .array(let cases)? = obj["cases"] else { throw Missing() }
        return try cases.map { c in
            guard case .object(let o) = c, case .string(let name)? = o["name"],
                  let input = o["input"], let expected = o["expected"] else { throw Missing() }
            return (name, input, expected)
        }
    }
}
