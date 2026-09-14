/// The reasons local device authentication (Face ID / Touch ID / passcode)
/// can fail to unlock the app. This is entirely separate from remote
/// authorization (`SessionManager` / Supabase JWT) — Face ID protects who
/// can *see* the app on this device, not who the backend thinks is making
/// a request.
enum LocalAuthenticationError: Error, Sendable, Equatable {
    case unavailable
    case failed
    case userCancelled
    case lockedOut
}

/// Abstracts `LAContext` so `AppLockController` can be unit-tested without
/// a real biometric prompt.
protocol LocalAuthenticationService: Sendable {
    func canAuthenticate() -> Bool
    func authenticate(reason: String) async throws
}
