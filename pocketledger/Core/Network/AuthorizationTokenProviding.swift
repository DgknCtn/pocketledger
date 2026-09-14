/// The seam `NetworkClient` uses to attach `Authorization: Bearer <token>`
/// to requests that need it, without knowing anything about Keychain,
/// Supabase sessions, or token refresh.
///
/// A concrete `SessionManager` actor conforms to this in a later phase
/// (Remote Authentication & Session); until then, `NetworkClient` can be
/// exercised in tests with a fake conformance.
protocol AuthorizationTokenProviding: Sendable {
    func validAccessToken() async throws -> String
}
