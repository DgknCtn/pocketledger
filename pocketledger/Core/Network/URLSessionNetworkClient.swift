import Foundation
import os

/// The concrete `NetworkClient`: `URLSession` + `RequestBuilder` +
/// centralized HTTP/PostgREST status-code handling.
///
/// `JSONDecoder` is `@unchecked Sendable` here on the assumption (true for
/// Foundation's implementation) that a configured, immutable decoder is
/// safe to use for concurrent decode calls — it is never mutated after
/// `init`.
final class URLSessionNetworkClient: NetworkClient, @unchecked Sendable {
    private let session: URLSession
    private let requestBuilder: RequestBuilder
    private let authorizationProvider: AuthorizationTokenProviding?
    private let decoder: JSONDecoder

    init(
        session: URLSession = URLSessionNetworkClient.makeDefaultSession(),
        requestBuilder: RequestBuilder,
        authorizationProvider: AuthorizationTokenProviding? = nil,
        decoder: JSONDecoder = APIJSONDecoder.make()
    ) {
        self.session = session
        self.requestBuilder = requestBuilder
        self.authorizationProvider = authorizationProvider
        self.decoder = decoder
    }

    /// A session configured so PocketLedger's own SwiftData cache remains
    /// the single, intentional local-data strategy — the HTTP cache is
    /// deliberately disabled rather than left as a second, invisible one.
    static func makeDefaultSession() -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        return URLSession(configuration: configuration)
    }

    func send<Response: Decodable & Sendable>(
        _ request: APIRequest<Response>
    ) async throws -> Response {
        let accessToken = try await resolveAccessToken(for: request)
        let urlRequest = try requestBuilder.urlRequest(for: request, accessToken: accessToken)

        let (data, response) = try await perform(urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        try validate(statusCode: httpResponse.statusCode, data: data)

        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            AppLogger.network.error("Decoding failed for \(request.path, privacy: .public): \(String(describing: error), privacy: .private)")
            throw NetworkError.decoding
        }
    }

    private func resolveAccessToken<Response>(for request: APIRequest<Response>) async throws -> String? {
        guard request.requiresAuth else { return nil }

        guard let authorizationProvider else {
            throw NetworkError.invalidRequest
        }

        return try await authorizationProvider.validAccessToken()
    }

    private func perform(_ urlRequest: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: urlRequest)
        } catch is CancellationError {
            throw NetworkError.cancelled
        } catch let error as URLError where error.code == .cancelled {
            throw NetworkError.cancelled
        } catch let error as URLError {
            throw NetworkError.transport(error.code)
        }
    }

    private func validate(statusCode: Int, data: Data) throws {
        switch statusCode {
        case 200..<300:
            return

        case 401:
            throw NetworkError.unauthorized

        case 403:
            throw NetworkError.forbidden

        case 429:
            throw NetworkError.rateLimited

        case 500...599:
            throw NetworkError.server(statusCode: statusCode)

        default:
            if let apiError = try? decoder.decode(PostgRESTErrorDTO.self, from: data) {
                throw NetworkError.api(
                    statusCode: statusCode,
                    code: apiError.code,
                    message: apiError.message
                )
            }
            throw NetworkError.api(statusCode: statusCode, code: nil, message: "")
        }
    }
}
