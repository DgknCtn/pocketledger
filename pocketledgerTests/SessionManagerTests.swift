import Foundation
import Testing
@testable import pocketledger

struct SessionManagerTests {
    private let fixedNow = Date(timeIntervalSince1970: 1_800_000_000)

    private func makeManager(
        authRemoteDataSource: FakeAuthRemoteDataSource,
        secureStore: FakeSecureStore = FakeSecureStore(),
        expirySafetyMargin: TimeInterval = 60
    ) -> SessionManager {
        SessionManager(
            authRemoteDataSource: authRemoteDataSource,
            secureStore: secureStore,
            expirySafetyMargin: expirySafetyMargin,
            now: { [fixedNow] in fixedNow }
        )
    }

    private func seedSession(
        in store: FakeSecureStore,
        expiresAt: Date,
        refreshToken: String = "stored-refresh-token"
    ) throws {
        let session = UserSession(
            userID: UUID(),
            accessToken: "stored-access-token",
            refreshToken: refreshToken,
            expiresAt: expiresAt
        )
        try store.save(JSONEncoder().encode(session), for: .userSession)
    }

    // MARK: - No stored session

    @Test func noStoredSessionCreatesAnonymousSession() async throws {
        let fake = FakeAuthRemoteDataSource(signUpResult: .success(.fixture(accessToken: "fresh-token")))
        let manager = makeManager(authRemoteDataSource: fake)

        let token = try await manager.validAccessToken()

        #expect(token == "fresh-token")
        #expect(await fake.signUpCallCount == 1)
        #expect(await fake.refreshCallCount == 0)
    }

    // MARK: - Valid stored session

    @Test func validStoredSessionReturnsAccessTokenWithoutNetworkCall() async throws {
        let store = FakeSecureStore()
        try seedSession(in: store, expiresAt: fixedNow.addingTimeInterval(3_600))
        let fake = FakeAuthRemoteDataSource()
        let manager = makeManager(authRemoteDataSource: fake, secureStore: store)

        let token = try await manager.validAccessToken()

        #expect(token == "stored-access-token")
        #expect(await fake.signUpCallCount == 0)
        #expect(await fake.refreshCallCount == 0)
    }

    // MARK: - Expiring session

    @Test func sessionExpiringWithinSafetyMarginTriggersRefresh() async throws {
        let store = FakeSecureStore()
        try seedSession(
            in: store,
            expiresAt: fixedNow.addingTimeInterval(10),
            refreshToken: "the-refresh-token"
        )
        let fake = FakeAuthRemoteDataSource(refreshResult: .success(.fixture(accessToken: "refreshed-token")))
        let manager = makeManager(authRemoteDataSource: fake, secureStore: store)

        let token = try await manager.validAccessToken()

        #expect(token == "refreshed-token")
        #expect(await fake.refreshCallCount == 1)
        #expect(await fake.signUpCallCount == 0)
    }

    @Test func successfulRefreshPersistsTheNewSession() async throws {
        let store = FakeSecureStore()
        try seedSession(in: store, expiresAt: fixedNow.addingTimeInterval(10))
        let fake = FakeAuthRemoteDataSource(refreshResult: .success(.fixture(accessToken: "refreshed-token")))
        let manager = makeManager(authRemoteDataSource: fake, secureStore: store)

        _ = try await manager.validAccessToken()

        let persistedData = try #require(try store.data(for: .userSession))
        let persisted = try JSONDecoder().decode(UserSession.self, from: persistedData)
        #expect(persisted.accessToken == "refreshed-token")
    }

    @Test func failedRefreshInvalidatesTheSessionAndThrows() async throws {
        let store = FakeSecureStore()
        try seedSession(in: store, expiresAt: fixedNow.addingTimeInterval(10))
        let fake = FakeAuthRemoteDataSource(refreshResult: .failure(FixtureError()))
        let manager = makeManager(authRemoteDataSource: fake, secureStore: store)

        await #expect(throws: SessionManager.SessionError.refreshFailed) {
            try await manager.validAccessToken()
        }

        #expect(try store.data(for: .userSession) == nil)
    }

    // MARK: - Concurrency

    @Test func fiveSimultaneousCallsWithNoSessionTriggerOnlyOneSignUp() async throws {
        let fake = FakeAuthRemoteDataSource(
            signUpResult: .success(.fixture(accessToken: "shared-token")),
            delay: .milliseconds(50)
        )
        let manager = makeManager(authRemoteDataSource: fake)

        let tokens = try await withThrowingTaskGroup(of: String.self) { group in
            for _ in 0..<5 {
                group.addTask { try await manager.validAccessToken() }
            }
            var collected: [String] = []
            for try await token in group {
                collected.append(token)
            }
            return collected
        }

        #expect(tokens.count == 5)
        #expect(tokens.allSatisfy { $0 == "shared-token" })
        #expect(await fake.signUpCallCount == 1)
    }

    // MARK: - currentUserID

    @Test func currentUserIDMatchesTheActiveSession() async throws {
        let userID = UUID()
        let fake = FakeAuthRemoteDataSource(signUpResult: .success(.fixture(userID: userID)))
        let manager = makeManager(authRemoteDataSource: fake)

        let resolvedUserID = try await manager.currentUserID()

        #expect(resolvedUserID == userID)
    }

    // MARK: - Manual invalidation

    @Test func invalidateSessionClearsCachedAndPersistedSession() async throws {
        let store = FakeSecureStore()
        try seedSession(in: store, expiresAt: fixedNow.addingTimeInterval(3_600))
        let fake = FakeAuthRemoteDataSource(signUpResult: .success(.fixture(accessToken: "new-token")))
        let manager = makeManager(authRemoteDataSource: fake, secureStore: store)

        try await manager.invalidateSession()
        let token = try await manager.validAccessToken()

        #expect(token == "new-token")
        #expect(await fake.signUpCallCount == 1)
    }
}
