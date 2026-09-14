import Foundation

/// Infrastructure-level networking failures. These carry technical detail
/// (status codes, `URLError.Code`) and are never shown to the user directly
/// — the Data layer maps them to semantic `RepositoryError`s (added once
/// repositories exist), and Presentation maps those to user-facing copy.
enum NetworkError: Error, Sendable, Equatable {
    case invalidRequest
    case transport(URLError.Code)
    case unauthorized
    case forbidden
    case rateLimited
    case server(statusCode: Int)
    case api(statusCode: Int, code: String?, message: String)
    case decoding
    case invalidResponse
    case cancelled
}
