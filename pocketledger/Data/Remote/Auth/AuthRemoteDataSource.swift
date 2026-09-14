import Foundation

/// The two unauthenticated Supabase Auth endpoints PocketLedger uses.
/// Neither requires — or is allowed to send — a user access token.
protocol AuthRemoteDataSource: Sendable {
    func createAnonymousSession() async throws -> AuthSessionDTO
    func refreshSession(refreshToken: String) async throws -> AuthSessionDTO
}

struct DefaultAuthRemoteDataSource: AuthRemoteDataSource {
    private struct RefreshRequestBody: Encodable, Sendable {
        let refreshToken: String

        enum CodingKeys: String, CodingKey {
            case refreshToken = "refresh_token"
        }
    }

    private let networkClient: NetworkClient
    private let encoder: JSONEncoder

    init(networkClient: NetworkClient, encoder: JSONEncoder = APIJSONEncoder.make()) {
        self.networkClient = networkClient
        self.encoder = encoder
    }

    func createAnonymousSession() async throws -> AuthSessionDTO {
        let request = APIRequest<AuthSessionDTO>(
            service: .auth,
            path: "signup",
            method: .post,
            body: Data("{}".utf8),
            requiresAuth: false
        )
        return try await networkClient.send(request)
    }

    func refreshSession(refreshToken: String) async throws -> AuthSessionDTO {
        let body = try encoder.encode(RefreshRequestBody(refreshToken: refreshToken))
        let request = APIRequest<AuthSessionDTO>(
            service: .auth,
            path: "token",
            method: .post,
            queryItems: [URLQueryItem(name: "grant_type", value: "refresh_token")],
            body: body,
            requiresAuth: false
        )
        return try await networkClient.send(request)
    }
}
