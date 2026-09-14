import Foundation

struct AuthUserDTO: Decodable, Sendable {
    let id: UUID
    let isAnonymous: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case isAnonymous = "is_anonymous"
    }
}

/// The response shape shared by `POST /auth/v1/signup` (anonymous) and
/// `POST /auth/v1/token?grant_type=refresh_token`. Fields PocketLedger does
/// not need are simply absent here — `Decodable` ignores unknown JSON keys.
struct AuthSessionDTO: Decodable, Sendable {
    let accessToken: String
    let tokenType: String
    let expiresIn: Int
    let refreshToken: String
    let user: AuthUserDTO

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
        case user
    }
}
