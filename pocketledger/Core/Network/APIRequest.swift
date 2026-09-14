import Foundation

/// A declarative description of one HTTP request. Feature/data-source code
/// builds one of these; `NetworkClient` turns it into a `URLRequest`,
/// executes it, and decodes the result. Neither type knows anything about
/// Transaction, Account, or any other domain concept.
struct APIRequest<Response: Decodable & Sendable>: Sendable {
    let service: APIService
    let path: String
    let method: HTTPMethod
    var queryItems: [URLQueryItem] = []
    var headers: [String: String] = [:]
    var body: Data? = nil

    /// Whether this request must carry `Authorization: Bearer <token>`.
    /// `false` for the two unauthenticated auth endpoints (`/signup`,
    /// `/token`); `true` for every Data API request.
    var requiresAuth: Bool = true
}
