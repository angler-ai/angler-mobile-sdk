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

    static func endpoint(domain: String, workspaceId: String) -> URL? {
        var c = URLComponents()
        c.scheme = "https"
        c.host = domain
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
