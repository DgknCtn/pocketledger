import Foundation

/// Owns the remote Supabase session lifecycle: loading a persisted session,
/// creating an anonymous one when none exists, refreshing it before it
/// expires, and — critically — serializing concurrent refresh attempts so
/// N simultaneous requests hitting an expired token trigger exactly one
/// network round-trip, not N.
///
/// Being an `actor` is what makes that serialization correct: every call
/// funnels through actor-isolated state, and a request already in flight is
/// awaited rather than duplicated.
actor SessionManager: AuthorizationTokenProviding {
    enum SessionError: Error, Sendable, Equatable {
        case refreshFailed
    }

    private let authRemoteDataSource: AuthRemoteDataSource
    private let secureStore: SecureStore
    private let expirySafetyMargin: TimeInterval
    private let now: @Sendable () -> Date

    private var cachedSession: UserSession?
    private var hasLoadedFromStore = false
    private var inFlightTask: Task<UserSession, Error>?

    init(
        authRemoteDataSource: AuthRemoteDataSource,
        secureStore: SecureStore,
        expirySafetyMargin: TimeInterval = 60,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.authRemoteDataSource = authRemoteDataSource
        self.secureStore = secureStore
        self.expirySafetyMargin = expirySafetyMargin
        self.now = now
    }

    func validAccessToken() async throws -> String {
        try await session().accessToken
    }

    func currentUserID() async throws -> UUID {
        try await session().userID
    }

    /// Discards any cached/persisted session (e.g. because the signed-in
    /// remote identity no longer matches locally-cached data — see the
    /// database specification's "session identity mismatch" policy).
    func invalidateSession() throws {
        inFlightTask = nil
        try clearSession()
    }

    // MARK: - Core flow

    private func session() async throws -> UserSession {
        if let inFlightTask {
            return try await inFlightTask.value
        }

        if hasLoadedFromStore, let cachedSession, !isExpiringSoon(cachedSession) {
            return cachedSession
        }

        // The task is assigned to `inFlightTask` before any `await` below,
        // so a call that arrives while this one is suspended always sees
        // it and awaits the same task instead of starting a second one.
        let task = Task { try await self.resolveSession() }
        inFlightTask = task

        defer { inFlightTask = nil }
        return try await task.value
    }

    private func resolveSession() async throws -> UserSession {
        if !hasLoadedFromStore {
            cachedSession = loadSessionFromStore()
            hasLoadedFromStore = true
        }

        guard let existing = cachedSession else {
            return try await createAnonymousSession()
        }

        guard isExpiringSoon(existing) else {
            return existing
        }

        return try await refresh(existing)
    }

    private func isExpiringSoon(_ session: UserSession) -> Bool {
        session.expiresAt.timeIntervalSince(now()) <= expirySafetyMargin
    }

    private func createAnonymousSession() async throws -> UserSession {
        let dto = try await authRemoteDataSource.createAnonymousSession()
        let session = UserSession(dto: dto, now: now())
        try persist(session)
        return session
    }

    private func refresh(_ session: UserSession) async throws -> UserSession {
        do {
            let dto = try await authRemoteDataSource.refreshSession(refreshToken: session.refreshToken)
            let refreshed = UserSession(dto: dto, now: now())
            try persist(refreshed)
            return refreshed
        } catch {
            try? clearSession()
            throw SessionError.refreshFailed
        }
    }

    // MARK: - Storage

    private func loadSessionFromStore() -> UserSession? {
        guard let data = try? secureStore.data(for: .userSession) else { return nil }
        return try? JSONDecoder().decode(UserSession.self, from: data)
    }

    private func persist(_ session: UserSession) throws {
        cachedSession = session
        hasLoadedFromStore = true
        let data = try JSONEncoder().encode(session)
        try secureStore.save(data, for: .userSession)
    }

    private func clearSession() throws {
        cachedSession = nil
        hasLoadedFromStore = true
        try secureStore.delete(.userSession)
    }
}
