import Foundation
import Testing
@testable import pocketledger

struct AccountRepositoryTests {
    private let currency = CurrencyCode(rawValue: "TRY")!
    private let userID = UUID()
    private let fixedNow = Date(timeIntervalSince1970: 1_800_000_000)

    private struct Fixture {
        let repository: DefaultAccountRepository
        let remote: FakeAccountRemoteDataSource
        let local: FakeAccountLocalStore
        let walletProfileLocal: FakeWalletProfileLocalStore
    }

    private func makeSessionManager() -> SessionManager {
        let store = FakeSecureStore()
        let session = UserSession(
            userID: userID,
            accessToken: "access",
            refreshToken: "refresh",
            expiresAt: fixedNow.addingTimeInterval(3_600)
        )
        try! store.save(try! JSONEncoder().encode(session), for: .userSession)
        return SessionManager(authRemoteDataSource: FakeAuthRemoteDataSource(), secureStore: store, now: { [fixedNow] in fixedNow })
    }

    private func makeFixture(withWalletProfile: Bool = true) -> Fixture {
        let remote = FakeAccountRemoteDataSource()
        let local = FakeAccountLocalStore()
        let walletProfileLocal = FakeWalletProfileLocalStore()
        if withWalletProfile {
            walletProfileLocal.seed(WalletProfile(baseCurrency: currency))
        }
        let repository = DefaultAccountRepository(
            remoteDataSource: remote,
            localStore: local,
            walletProfileLocalStore: walletProfileLocal,
            sessionManager: makeSessionManager()
        )
        return Fixture(repository: repository, remote: remote, local: local, walletProfileLocal: walletProfileLocal)
    }

    private func accountDTO(
        id: UUID = UUID(),
        name: String = "Main Account",
        kind: String = "bank",
        openingBalanceMinor: Int64 = 100_000,
        isArchived: Bool = false,
        archivedAt: Date? = nil
    ) -> AccountDTO {
        AccountDTO(
            id: id, userID: userID, name: name, kind: kind,
            openingBalanceMinor: openingBalanceMinor, isArchived: isArchived, archivedAt: archivedAt,
            createdAt: fixedNow, updatedAt: fixedNow
        )
    }

    // MARK: - Cached reads

    @Test func cachedAccountsReturnsWhatIsInLocalStore() async throws {
        let fixture = makeFixture()
        let account = Account(
            id: UUID(), name: "Cash", kind: .cash,
            openingBalance: Money(minorUnits: 500, currency: currency),
            isArchived: false, archivedAt: nil, createdAt: fixedNow, updatedAt: fixedNow
        )
        fixture.local.seed(account)

        let result = try await fixture.repository.cachedAccounts()

        #expect(result == [account])
    }

    @Test func cachedAccountsThrowsWalletProfileMissingWithoutAProfile() async {
        let fixture = makeFixture(withWalletProfile: false)

        await #expect(throws: RepositoryError.walletProfileMissing) {
            try await fixture.repository.cachedAccounts()
        }
    }

    // MARK: - Refresh (remote success and failure)

    @Test func refreshAccountsMapsAndReconcilesTheCache() async throws {
        let fixture = makeFixture()
        fixture.remote.seed(accountDTO(name: "From Server"))

        let result = try await fixture.repository.refreshAccounts()

        #expect(result.map(\.name) == ["From Server"])
        let cached = try await fixture.local.fetchAll(userID: userID, currency: currency)
        #expect(cached.map(\.name) == ["From Server"])
    }

    @Test func refreshAccountsRemovesStaleCachedAccountsNotInTheAuthoritativeResponse() async throws {
        let fixture = makeFixture()
        fixture.local.seed(
            Account(
                id: UUID(), name: "Deleted On Server", kind: .bank,
                openingBalance: Money(minorUnits: 0, currency: currency),
                isArchived: false, archivedAt: nil, createdAt: fixedNow, updatedAt: fixedNow
            )
        )
        // Remote has nothing — an authoritative empty set.

        _ = try await fixture.repository.refreshAccounts()

        let cached = try await fixture.local.fetchAll(userID: userID, currency: currency)
        #expect(cached.isEmpty)
    }

    @Test func refreshFailureWithExistingCachePreservesTheCache() async throws {
        let fixture = makeFixture()
        let cachedAccount = Account(
            id: UUID(), name: "Still Here", kind: .bank,
            openingBalance: Money(minorUnits: 0, currency: currency),
            isArchived: false, archivedAt: nil, createdAt: fixedNow, updatedAt: fixedNow
        )
        fixture.local.seed(cachedAccount)
        fixture.remote.fetchAllError = NetworkError.transport(.notConnectedToInternet)

        await #expect(throws: RepositoryError.offline) {
            try await fixture.repository.refreshAccounts()
        }

        let cached = try await fixture.local.fetchAll(userID: userID, currency: currency)
        #expect(cached == [cachedAccount])
    }

    @Test func refreshFailureWithNoCacheThrowsMappedError() async {
        let fixture = makeFixture()
        fixture.remote.fetchAllError = NetworkError.server(statusCode: 500)

        await #expect(throws: RepositoryError.serviceUnavailable) {
            try await fixture.repository.refreshAccounts()
        }
    }

    // MARK: - Create

    @Test func createAccountSucceedsAndCachesTheServerCanonicalRecord() async throws {
        let fixture = makeFixture()
        let input = CreateAccountInput(
            id: UUID(), name: "New Account", kind: .bank,
            openingBalance: Money(minorUnits: 42_000, currency: currency)
        )

        let created = try await fixture.repository.createAccount(input)

        #expect(created.name == "New Account")
        let cached = try await fixture.local.fetchAll(userID: userID, currency: currency)
        #expect(cached.map(\.id) == [created.id])
    }

    @Test func createAccountRemoteSuccessWithLocalSaveFailureStillReturnsTheAccount() async throws {
        let fixture = makeFixture()
        fixture.local.failUpsert = true
        let input = CreateAccountInput(
            id: UUID(), name: "New Account", kind: .bank,
            openingBalance: Money(minorUnits: 1_000, currency: currency)
        )

        // The remote write is canonical and already succeeded — a cache
        // failure must not turn this into a thrown error, or the user
        // would see their successfully-created account reported as failed.
        let created = try await fixture.repository.createAccount(input)

        #expect(created.name == "New Account")
    }

    @Test func createAccountRemoteFailureThrowsAndDoesNotTouchTheCache() async throws {
        let fixture = makeFixture()
        fixture.remote.createError = NetworkError.server(statusCode: 500)
        let input = CreateAccountInput(
            id: UUID(), name: "New Account", kind: .bank,
            openingBalance: Money(minorUnits: 1_000, currency: currency)
        )

        await #expect(throws: RepositoryError.serviceUnavailable) {
            try await fixture.repository.createAccount(input)
        }

        let cached = try await fixture.local.fetchAll(userID: userID, currency: currency)
        #expect(cached.isEmpty)
    }

    // MARK: - Update

    @Test func updateAccountPreservesArchiveStateFromTheServer() async throws {
        let fixture = makeFixture()
        let id = UUID()
        fixture.remote.seed(accountDTO(id: id, name: "Old Name", isArchived: true, archivedAt: fixedNow))

        let updated = try await fixture.repository.updateAccount(
            UpdateAccountInput(id: id, name: "New Name", openingBalance: Money(minorUnits: 5_000, currency: currency))
        )

        #expect(updated.name == "New Name")
        #expect(updated.isArchived == true)
        #expect(updated.archivedAt == fixedNow)
    }

    // MARK: - Archive

    @Test func archiveAccountSetsArchivedFieldsAndUpdatesCache() async throws {
        let fixture = makeFixture()
        let id = UUID()
        fixture.remote.seed(accountDTO(id: id, name: "To Archive"))

        let archived = try await fixture.repository.archiveAccount(id: id)

        #expect(archived.isArchived == true)
        #expect(archived.archivedAt != nil)
        let cached = try await fixture.local.fetchAll(userID: userID, currency: currency)
        #expect(cached.first?.isArchived == true)
    }

    // MARK: - Delete

    @Test func deleteAccountRemovesItFromTheCacheOnRemoteSuccess() async throws {
        let fixture = makeFixture()
        let id = UUID()
        fixture.remote.seed(accountDTO(id: id))
        fixture.local.seed(
            Account(
                id: id, name: "To Delete", kind: .bank,
                openingBalance: Money(minorUnits: 0, currency: currency),
                isArchived: false, archivedAt: nil, createdAt: fixedNow, updatedAt: fixedNow
            )
        )

        try await fixture.repository.deleteAccount(id: id)

        let cached = try await fixture.local.fetchAll(userID: userID, currency: currency)
        #expect(cached.isEmpty)
    }

    @Test func deleteAccountWithTransactionsMapsForeignKeyViolationToASpecificError() async throws {
        let fixture = makeFixture()
        let id = UUID()
        fixture.local.seed(
            Account(
                id: id, name: "Has Transactions", kind: .bank,
                openingBalance: Money(minorUnits: 0, currency: currency),
                isArchived: false, archivedAt: nil, createdAt: fixedNow, updatedAt: fixedNow
            )
        )
        fixture.remote.deleteError = NetworkError.api(statusCode: 409, code: "23503", message: "fk violation")

        await #expect(throws: RepositoryError.accountHasTransactions) {
            try await fixture.repository.deleteAccount(id: id)
        }

        // The remote delete was refused, so the cached row must remain.
        let cached = try await fixture.local.fetchAll(userID: userID, currency: currency)
        #expect(cached.map(\.id) == [id])
    }

    @Test func deleteAccountRemoteFailureLeavesTheCachedItemInPlace() async throws {
        let fixture = makeFixture()
        let id = UUID()
        fixture.local.seed(
            Account(
                id: id, name: "Still Here", kind: .bank,
                openingBalance: Money(minorUnits: 0, currency: currency),
                isArchived: false, archivedAt: nil, createdAt: fixedNow, updatedAt: fixedNow
            )
        )
        fixture.remote.deleteError = NetworkError.server(statusCode: 500)

        await #expect(throws: RepositoryError.serviceUnavailable) {
            try await fixture.repository.deleteAccount(id: id)
        }

        let cached = try await fixture.local.fetchAll(userID: userID, currency: currency)
        #expect(cached.map(\.id) == [id])
    }
}
