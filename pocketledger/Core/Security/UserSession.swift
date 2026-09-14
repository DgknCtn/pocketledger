import Foundation

/// The remote (Supabase) session PocketLedger persists — entirely separate
/// from local Face ID app-lock state. This is what identifies which
/// backend user's rows RLS will expose, not who is holding the phone.
struct UserSession: Sendable, Codable, Equatable {
    let userID: UUID
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
}

extension UserSession {
    init(dto: AuthSessionDTO, now: Date = Date()) {
        self.init(
            userID: dto.user.id,
            accessToken: dto.accessToken,
            refreshToken: dto.refreshToken,
            expiresAt: now.addingTimeInterval(TimeInterval(dto.expiresIn))
        )
    }
}
