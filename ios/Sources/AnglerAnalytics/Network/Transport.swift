import Foundation

protocol Transport {
    /// Calls back with the HTTP status, or nil for a network error or timeout.
    func send(_ body: Data, completion: @escaping (Int?) -> Void)
}

final class URLSessionTransport: Transport {
    static let timeout: TimeInterval = 15

    private let endpoint: URL
    private let token: String
    private let session: URLSession

    init(endpoint: URL, token: String) {
        self.endpoint = endpoint
        self.token = token
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = Self.timeout
        config.timeoutIntervalForResource = Self.timeout
        config.waitsForConnectivity = false
        session = URLSession(configuration: config)
    }

    /// `https://{domain}/v1/workspaces/{workspaceId}/events`. Accepts a bare host (optionally
    /// with a port) and tolerates a leading `https://` / `http://` and a trailing `/`. Nil for
    /// anything else, so a typo fails loudly at configure instead of losing every event.
    static func endpoint(domain: String, workspaceId: String) -> URL? {
        var host = domain.trimmingCharacters(in: .whitespacesAndNewlines)
        for scheme in ["https://", "http://"] where host.lowercased().hasPrefix(scheme) {
            host = String(host.dropFirst(scheme.count))
        }
        while host.hasSuffix("/") { host.removeLast() }
        guard host.range(of: #"^[A-Za-z0-9.-]+(:[0-9]{1,5})?$"#, options: .regularExpression) != nil else { return nil }
        let parts = host.split(separator: ":", maxSplits: 1)
        var c = URLComponents()
        c.scheme = "https"
        c.host = String(parts[0])
        if parts.count == 2 { c.port = Int(parts[1]) }
        c.path = "/v1/workspaces/\(workspaceId)/events"
        return c.url
    }

    func send(_ body: Data, completion: @escaping (Int?) -> Void) {
        var request = URLRequest(url: endpoint, timeoutInterval: Self.timeout)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = body
        session.dataTask(with: request) { _, response, error in
            if error != nil { return completion(nil) }
            completion((response as? HTTPURLResponse)?.statusCode)
        }.resume()
    }
}
