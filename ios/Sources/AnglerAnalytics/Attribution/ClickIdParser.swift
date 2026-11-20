import Foundation

/// URL or query string → identifier map (design §6.1): ad click IDs, plus the browser IDs a
/// website can pass to the app in a link (its `_fbp`, `_ga` … cookies), so app events can be
/// tied to the web visitor. Takes strings rather than `URL` because Foundation may reject or
/// rewrite invalid percent-encoding.
enum ClickIdParser {
    /// Query parameter (case-sensitive, after one leading `_` is dropped) → identifier name.
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
        // Browser IDs, named as the web SDKs send them.
        "fbp": "fbp",
        "fbc": "fbc",
        "ga": "ga",
        "ttp": "ttp",
        "scid": "scid",
        "pin_unauth": "pin_unauth",
        "rdt_uuid": "rdt_uuid",
    ]

    /// The query is the text after the first `?` and before any `#`. Any scheme works.
    static func parse(url: String) -> [String: String] {
        guard let q = url.firstIndex(of: "?") else { return [:] }
        var query = url[url.index(after: q)...]
        if let hash = query.firstIndex(of: "#") { query = query[..<hash] }
        return parse(query: String(query))
    }

    /// Splits on `&`, then each pair at the first `=`. Percent-decodes name and value
    /// (`+` stays `+`) and drops one leading `_` from the name, so `_fbp` is `fbp`. Empty
    /// values and invalid encodings are skipped; the first remaining occurrence wins.
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
            guard let decoded = rawName.removingPercentEncoding,
                  let id = identifierByParameter[decoded.hasPrefix("_") ? String(decoded.dropFirst()) : decoded],
                  result[id] == nil,
                  let value = rawValue.removingPercentEncoding,
                  !value.isEmpty
            else { continue }
            result[id] = value
        }
        return result
    }
}
