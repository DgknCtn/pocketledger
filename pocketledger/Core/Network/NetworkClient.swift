/// Turns a typed `APIRequest` into a decoded response, or a typed
/// `NetworkError`. Implementations know nothing about Transaction, Account,
/// Dashboard, Analytics or SwiftData — only HTTP.
protocol NetworkClient: Sendable {
    func send<Response: Decodable & Sendable>(_ request: APIRequest<Response>) async throws -> Response
}
