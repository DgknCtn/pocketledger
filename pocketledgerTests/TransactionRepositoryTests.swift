import Foundation
import Testing
@testable import pocketledger

struct TransactionRepositoryTests {
    private let currency = CurrencyCode(rawValue: "TRY")!
    private let userID = UUID()
    private let fixedNow = Date(timeIntervalSince1970: 1_800_000_000)

    private struct Fixture {
        let repository: DefaultTransactionRepository
        let remote: FakeTransactionRemoteDataSource
        let local: FakeTransactionLocalStore
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

    private func makeFixture() -> Fixture {
        let remote = FakeTransactionRemoteDataSource()
        let local = FakeTransactionLocalStore()
        let walletProfileLocal = FakeWalletProfileLocalStore()
        walletProfileLocal.seed(WalletProfile(baseCurrency: currency))
        let repository = DefaultTransactionRepository(
            remoteDataSource: remote,
            localStore: local,
            walletProfileLocalStore: walletProfileLocal,
            sessionManager: makeSessionManager()
        )
        return Fixture(repository: repository, remote: remote, local: local)
    }

    private func newTransaction(
        id: UUID = UUID(),
        kind: TransactionKind = .expense,
        source: UUID = UUID(),
        destination: UUID? = nil,
        amountMinor: Int64 = 5_000,
        category: TransactionCategory? = .food,
        date: String = "2026-09-14"
    ) -> NewTransaction {
        NewTransaction(
            id: id, kind: kind, sourceAccountID: source, destinationAccountID: destination,
            amount: Money(minorUnits: amountMinor, currency: currency), category: category,
            title: "Lunch", note: nil, date: try! LocalDate(parsing: date)
        )
    }

    private func transactionDTO(id: UUID, accountID: UUID) -> TransactionDTO {
        TransactionDTO(
            id: id, userID: userID, kind: "expense", accountID: accountID, destinationAccountID: nil,
            amountMinor: 5_000, category: "food", title: "Lunch", note: nil,
            transactionDate: "2026-09-14", createdAt: fixedNow, updatedAt: fixedNow
        )
    }

    // MARK: - Refresh

    @Test func refreshTransactionsReconcilesTheCache() async throws {
        let fixture = makeFixture()
        let staleID = UUID()
        fixture.local.seed(
            Transaction(
                id: staleID, kind: .expense, sourceAccountID: UUID(), destinationAccountID: nil,
                amount: Money(minorUnits: 100, currency: currency), category: .food,
                title: "Stale", note: nil, date: try LocalDate(parsing: "2026-08-01"),
                createdAt: fixedNow, updatedAt: fixedNow
            )
        )
        let freshID = UUID()
        fixture.remote.seed(transactionDTO(id: freshID, accountID: UUID()))

        let result = try await fixture.repository.refreshTransactions()

        #expect(result.map(\.id) == [freshID])
        let cached = try await fixture.local.fetchAll(userID: userID, currency: currency)
        #expect(cached.map(\.id) == [freshID])
    }

    @Test func refreshFailureKeepsCachedTransactions() async throws {
        let fixture = makeFixture()
        let cachedTransaction = Transaction(
            id: UUID(), kind: .income, sourceAccountID: UUID(), destinationAccountID: nil,
            amount: Money(minorUnits: 1_000, currency: currency), category: nil,
            title: "Salary", note: nil, date: try LocalDate(parsing: "2026-09-01"),
            createdAt: fixedNow, updatedAt: fixedNow
        )
        fixture.local.seed(cachedTransaction)
        fixture.remote.fetchAllError = NetworkError.transport(.notConnectedToInternet)

        await #expect(throws: RepositoryError.offline) {
            try await fixture.repository.refreshTransactions()
        }

        let cached = try await fixture.local.fetchAll(userID: userID, currency: currency)
        #expect(cached == [cachedTransaction])
    }

    // MARK: - Create

    @Test func createTransactionCachesTheServerCanonicalRecord() async throws {
        let fixture = makeFixture()
        let input = newTransaction()

        let created = try await fixture.repository.createTransaction(input)

        #expect(created.id == input.id)
        let cached = try await fixture.local.fetchAll(userID: userID, currency: currency)
        #expect(cached.map(\.id) == [input.id])
    }

    @Test func createTransactionRemoteSuccessWithLocalSaveFailureStillReturnsTheTransaction() async throws {
        let fixture = makeFixture()
        fixture.local.failUpsert = true
        let input = newTransaction()

        let created = try await fixture.repository.createTransaction(input)

        #expect(created.id == input.id)
    }

    @Test func createTransactionInvalidPayloadFailsWithoutReachingTheCache() async throws {
        let fixture = makeFixture()
        fixture.remote.createError = NetworkError.api(statusCode: 400, code: "23514", message: "invalid shape")
        let input = newTransaction()

        await #expect(throws: RepositoryError.self) {
            try await fixture.repository.createTransaction(input)
        }

        let cached = try await fixture.local.fetchAll(userID: userID, currency: currency)
        #expect(cached.isEmpty)
    }

    @Test func duplicateCreateConflictReconcilesByFetchingTheCanonicalRecord() async throws {
        let fixture = makeFixture()
        let input = newTransaction()
        // Simulate: an earlier POST with this same client-generated UUID
        // actually succeeded server-side, but the client never saw the
        // response (connection dropped). The retry now gets 23505.
        fixture.remote.seed(transactionDTO(id: input.id, accountID: input.sourceAccountID))
        fixture.remote.createError = NetworkError.api(statusCode: 409, code: "23505", message: "duplicate key")

        let result = try await fixture.repository.createTransaction(input)

        #expect(result.id == input.id)
        let cached = try await fixture.local.fetchAll(userID: userID, currency: currency)
        #expect(cached.map(\.id) == [input.id])
    }

    // MARK: - Update / Delete

    @Test func updateTransactionSendsTheCompleteMutableStateAndUpdatesTheCache() async throws {
        let fixture = makeFixture()
        let id = UUID()
        let accountID = UUID()
        fixture.remote.seed(transactionDTO(id: id, accountID: accountID))
        fixture.local.seed(
            Transaction(
                id: id, kind: .expense, sourceAccountID: accountID, destinationAccountID: nil,
                amount: Money(minorUnits: 5_000, currency: currency), category: .food,
                title: "Lunch", note: nil, date: try LocalDate(parsing: "2026-09-14"),
                createdAt: fixedNow, updatedAt: fixedNow
            )
        )

        let edited = newTransaction(id: id, source: accountID, amountMinor: 9_000, category: .shopping)
        let updated = try await fixture.repository.updateTransaction(id: id, input: edited)

        #expect(updated.amount.minorUnits == 9_000)
        #expect(updated.category == .shopping)
        let cached = try await fixture.local.fetchAll(userID: userID, currency: currency)
        #expect(cached.first?.amount.minorUnits == 9_000)
    }

    @Test func deleteTransactionRemoteFailureLeavesTheCachedItemInPlace() async throws {
        let fixture = makeFixture()
        let id = UUID()
        fixture.local.seed(
            Transaction(
                id: id, kind: .expense, sourceAccountID: UUID(), destinationAccountID: nil,
                amount: Money(minorUnits: 1_000, currency: currency), category: .food,
                title: "Test", note: nil, date: try LocalDate(parsing: "2026-09-14"),
                createdAt: fixedNow, updatedAt: fixedNow
            )
        )
        fixture.remote.deleteError = NetworkError.server(statusCode: 500)

        await #expect(throws: RepositoryError.serviceUnavailable) {
            try await fixture.repository.deleteTransaction(id: id)
        }

        let cached = try await fixture.local.fetchAll(userID: userID, currency: currency)
        #expect(cached.map(\.id) == [id])
    }

    @Test func deleteTransactionRemoteSuccessRemovesItFromTheCache() async throws {
        let fixture = makeFixture()
        let id = UUID()
        fixture.remote.seed(transactionDTO(id: id, accountID: UUID()))
        fixture.local.seed(
            Transaction(
                id: id, kind: .expense, sourceAccountID: UUID(), destinationAccountID: nil,
                amount: Money(minorUnits: 1_000, currency: currency), category: .food,
                title: "Test", note: nil, date: try LocalDate(parsing: "2026-09-14"),
                createdAt: fixedNow, updatedAt: fixedNow
            )
        )

        try await fixture.repository.deleteTransaction(id: id)

        let cached = try await fixture.local.fetchAll(userID: userID, currency: currency)
        #expect(cached.isEmpty)
    }
}
