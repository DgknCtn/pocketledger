import Foundation
import Testing
@testable import pocketledger

struct WalletProfileRepositoryTests {
    private let userID = UUID()
    private let fixedNow = Date(timeIntervalSince1970: 1_800_000_000)

    private struct Fixture {
        let repository: DefaultWalletProfileRepository
        let remote: FakeWalletProfileRemoteDataSource
        let local: FakeWalletProfileLocalStore
    }

    private func makeSessionManager() -> SessionManager {
        let store = FakeSecureStore()
        let session = UserSession(
            userID: userID, accessToken: "a", refreshToken: "r",
            expiresAt: fixedNow.addingTimeInterval(3_600)
        )
        try! store.save(try! JSONEncoder().encode(session), for: .userSession)
        return SessionManager(authRemoteDataSource: FakeAuthRemoteDataSource(), secureStore: store, now: { [fixedNow] in fixedNow })
    }

    private func makeFixture() -> Fixture {
        let remote = FakeWalletProfileRemoteDataSource()
        let local = FakeWalletProfileLocalStore()
        let repository = DefaultWalletProfileRepository(
            remoteDataSource: remote, localStore: local, sessionManager: makeSessionManager()
        )
        return Fixture(repository: repository, remote: remote, local: local)
    }

    @Test func cachedProfileReturnsWhatIsLocallyStored() async throws {
        let fixture = makeFixture()
        let profile = WalletProfile(baseCurrency: CurrencyCode(rawValue: "USD")!)
        fixture.local.seed(profile)

        let result = try await fixture.repository.cachedProfile()

        #expect(result == profile)
    }

    @Test func refreshProfileReturnsNilWhenNoneExistsYetRatherThanThrowing() async throws {
        let fixture = makeFixture()

        let result = try await fixture.repository.refreshProfile()

        #expect(result == nil)
    }

    @Test func refreshProfileCachesTheFetchedProfile() async throws {
        let fixture = makeFixture()
        fixture.remote.seed(
            WalletProfileDTO(userID: userID, baseCurrencyCode: "EUR", createdAt: fixedNow, updatedAt: fixedNow)
        )

        let result = try await fixture.repository.refreshProfile()

        #expect(result?.baseCurrency.rawValue == "EUR")
        let cached = try await fixture.local.fetch(userID: userID)
        #expect(cached?.baseCurrency.rawValue == "EUR")
    }

    @Test func createProfileSendsTheChosenCurrencyAndCachesTheResult() async throws {
        let fixture = makeFixture()
        let currency = CurrencyCode(rawValue: "TRY")!

        let created = try await fixture.repository.createProfile(baseCurrency: currency)

        #expect(created.baseCurrency == currency)
        let cached = try await fixture.local.fetch(userID: userID)
        #expect(cached == created)
    }

    @Test func createProfileFailureThrowsMappedError() async {
        let fixture = makeFixture()
        fixture.remote.createError = NetworkError.unauthorized

        await #expect(throws: RepositoryError.unauthorized) {
            try await fixture.repository.createProfile(baseCurrency: CurrencyCode(rawValue: "TRY")!)
        }
    }
}
