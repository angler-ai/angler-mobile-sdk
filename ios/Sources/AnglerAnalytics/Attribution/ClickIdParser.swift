import Foundation

/// URL or query string → click-ID map (design §6.1). Takes strings rather than `URL`
/// because Foundation may reject or rewrite invalid percent-encoding.
enum ClickIdParser {
    /// Query parameter (case-sensitive) → identifier name.
    static let identifierByParameter: [String: String] = [
        "gclid": "gclid",
        "gbraid": "gbraid",
        "wbraid": "wbraid",
        "gad_source": "gad_source",
        "fbclid": "fbclid",
        "ttclid": "ttclid",
        "ScCid": "sccid",
        "rdt_cid": "rdt_cid",
        "epik": "epik",
    ]

    /// The query is the text after the first `?` and before any `#`. Any scheme works.
    static func parse(url: String) -> [String: String] {
        guard let q = url.firstIndex(of: "?") else { return [:] }
        var query = url[url.index(after: q)...]
        if let hash = query.firstIndex(of: "#") { query = query[..<hash] }
        return parse(query: String(query))
    }

    /// Splits on `&`, then each pair at the first `=`. Percent-decodes name and value
    /// (`+` stays `+`). Empty values and invalid encodings are skipped; the first
    /// remaining occurrence of a parameter wins.
    static func parse(query: String) -> [String: String] {
        var result: [String: String] = [:]
        for pair in query.split(separator: "&", omittingEmptySubsequences: true) {
            let rawName: Substring
            let rawValue: Substring
            if let eq = pair.firstIndex(of: "=") {
                rawName = pair[..<eq]
                rawValue = pair[pair.index(after: eq)...]
            } else {
                rawName = pair
                rawValue = ""
            }
            guard let name = rawName.removingPercentEncoding,
                  let id = identifierByParameter[name],
                  result[id] == nil,
                  let value = rawValue.removingPercentEncoding,
                  !value.isEmpty
            else { continue }
            result[id] = value
        }
        return result
    }
}
