import Foundation

extension AnglerData {
    /// The `data` object sent to data-api (null fields left out).
    var jsonObject: [String: JSONValue] {
        let encoder = JSONEncoder()
        guard let encoded = try? encoder.encode(self),
              let value = try? JSONDecoder().decode(JSONValue.self, from: encoded) else {
            Log.warning("couldn't encode AnglerData; sending the event without it")
            return [:]
        }
        return value.objectValue ?? [:]
    }
}
