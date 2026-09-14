import Foundation
import SwiftData
import Testing
@testable import pocketledger

struct PersistenceActorTests {
    private let currency = CurrencyCode(rawValue: "TRY")!
    private let userID = UUID()

    private func makeActor() -> PersistenceActor {
        PersistenceActor(modelContainer: PersistenceContainer.makeInMemory())
    }

    private func makeAccount(
        id: UUID = UUID(),
        name: String = "Main Account",
        kind: AccountKind = .bank,
        openingMinor: Int64 = 100_000,
        isArchived: Bool = false
    ) -> Account {
        Account(
            id: id,
            name: name,
            kind: kind,
            openingBalance: Money(minorUnits: openingMinor, currency: currency),
            isArchived: isArchived,
            archivedAt: isArchived ? Date() : nil,
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    private func makeTransaction(
        id: UUID = UUID(),
        kind: TransactionKind = .expense,
        source: UUID,
        destination: UUID? = nil,
        amountMinor: Int64 = 5_000,
        category: TransactionCategory? = .food,
        date: LocalDate
    ) -> Transaction {
        Transaction(
            id: id,
            kind: kind,
            sourceAccountID: source,
            destinationAccountID: destination,
            amount: Money(minorUnits: amountMinor, currency: currency),
            category: category,
            title: "Test transaction",
            note: nil,
            date: date,
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    // MARK: - Wallet profile

    @Test func walletProfileRoundTripsThroughUpsertAndFetch() async throws {
        let actor = makeActor()
        let profile = WalletProfile(baseCurrency: currency)

        try await actor.upsertWalletProfile(profile, userID: userID)
        let fetched = try await actor.fetchWalletProfile(userID: userID)

        #expect(fetched == profile)
    }

    @Test func upsertingWalletProfileTwiceUpdatesRatherThanDuplicates() async throws {
        let actor = makeActor()
        try await actor.upsertWalletProfile(WalletProfile(baseCurrency: currency), userID: userID)

        let usd = CurrencyCode(rawValue: "USD")!
        try await actor.upsertWalletProfile(WalletProfile(baseCurrency: usd), userID: userID)

        let fetched = try await actor.fetchWalletProfile(userID: userID)
        #expect(fetched?.baseCurrency == usd)
    }

    @Test func missingWalletProfileReturnsNilNotAnError() async throws {
        let actor = makeActor()

        let fetched = try await actor.fetchWalletProfile(userID: userID)

        #expect(fetched == nil)
    }

    // MARK: - Account insert / update / delete

    @Test func accountInsertThenFetchRoundTrips() async throws {
        let actor = makeActor()
        let account = makeAccount(name: "Cash Wallet", kind: .cash, openingMinor: 25_000)

        try await actor.upsertAccount(account, userID: userID)
        let accounts = try await actor.fetchAccounts(userID: userID, currency: currency)

        #expect(accounts == [account])
    }

    @Test func upsertingAnAccountWithTheSameIDUpdatesItInPlace() async throws {
        let actor = makeActor()
        let id = UUID()
        try await actor.upsertAccount(makeAccount(id: id, name: "Old Name"), userID: userID)

        let updated = makeAccount(id: id, name: "New Name", openingMinor: 999_000)
        try await actor.upsertAccount(updated, userID: userID)

        let accounts = try await actor.fetchAccounts(userID: userID, currency: currency)
        #expect(accounts.count == 1)
        #expect(accounts.first?.name == "New Name")
        #expect(accounts.first?.openingBalance.minorUnits == 999_000)
    }

    @Test func deletingAnAccountRemovesItFromFutureFetches() async throws {
        let actor = makeActor()
        let account = makeAccount()
        try await actor.upsertAccount(account, userID: userID)

        try await actor.deleteAccount(id: account.id)

        let accounts = try await actor.fetchAccounts(userID: userID, currency: currency)
        #expect(accounts.isEmpty)
    }

    @Test func deletingAnUnknownAccountIDDoesNotThrow() async throws {
        let actor = makeActor()

        try await actor.deleteAccount(id: UUID())
    }

    @Test func accountsAreSortedByCreationOrder() async throws {
        let actor = makeActor()
        let first = Account(
            id: UUID(), name: "First", kind: .bank,
            openingBalance: Money(minorUnits: 0, currency: currency),
            isArchived: false, archivedAt: nil,
            createdAt: Date(timeIntervalSince1970: 1_000), updatedAt: Date()
        )
        let second = Account(
            id: UUID(), name: "Second", kind: .bank,
            openingBalance: Money(minorUnits: 0, currency: currency),
            isArchived: false, archivedAt: nil,
            createdAt: Date(timeIntervalSince1970: 2_000), updatedAt: Date()
        )

        // Insert out of order to prove the fetch, not the insert order, sorts.
        try await actor.upsertAccount(second, userID: userID)
        try await actor.upsertAccount(first, userID: userID)

        let accounts = try await actor.fetchAccounts(userID: userID, currency: currency)
        #expect(accounts.map(\.name) == ["First", "Second"])
    }

    // MARK: - Transaction insert / update / delete

    @Test func transactionInsertThenFetchRoundTrips() async throws {
        let actor = makeActor()
        let accountID = UUID()
        let transaction = makeTransaction(
            source: accountID,
            date: try LocalDate(parsing: "2026-09-14")
        )

        try await actor.upsertTransaction(transaction, userID: userID)
        let transactions = try await actor.fetchTransactions(userID: userID, currency: currency)

        #expect(transactions == [transaction])
    }

    @Test func editingATransactionChangesAmountAndCategory() async throws {
        let actor = makeActor()
        let id = UUID()
        let accountID = UUID()
        try await actor.upsertTransaction(
            makeTransaction(id: id, source: accountID, amountMinor: 500, category: .food, date: try LocalDate(parsing: "2026-09-14")),
            userID: userID
        )

        let edited = makeTransaction(
            id: id, source: accountID, amountMinor: 750, category: .shopping, date: try LocalDate(parsing: "2026-09-14")
        )
        try await actor.upsertTransaction(edited, userID: userID)

        let transactions = try await actor.fetchTransactions(userID: userID, currency: currency)
        #expect(transactions.count == 1)
        #expect(transactions.first?.amount.minorUnits == 750)
        #expect(transactions.first?.category == .shopping)
    }

    @Test func deletingATransactionRemovesItFromFutureFetches() async throws {
        let actor = makeActor()
        let transaction = makeTransaction(source: UUID(), date: try LocalDate(parsing: "2026-09-14"))
        try await actor.upsertTransaction(transaction, userID: userID)

        try await actor.deleteTransaction(id: transaction.id)

        let transactions = try await actor.fetchTransactions(userID: userID, currency: currency)
        #expect(transactions.isEmpty)
    }

    @Test func transactionsAreSortedNewestFirst() async throws {
        let actor = makeActor()
        let accountID = UUID()
        let older = makeTransaction(source: accountID, date: try LocalDate(parsing: "2026-09-01"))
        let newer = makeTransaction(source: accountID, date: try LocalDate(parsing: "2026-09-14"))

        try await actor.upsertTransaction(older, userID: userID)
        try await actor.upsertTransaction(newer, userID: userID)

        let transactions = try await actor.fetchTransactions(userID: userID, currency: currency)
        #expect(transactions.map(\.id) == [newer.id, older.id])
    }

    @Test func transferAndIncomeAndExpenseFieldsRoundTripCorrectly() async throws {
        let actor = makeActor()
        let source = UUID()
        let destination = UUID()
        let transfer = makeTransaction(
            kind: .transfer, source: source, destination: destination,
            amountMinor: 30_000, category: nil, date: try LocalDate(parsing: "2026-09-14")
        )

        try await actor.upsertTransaction(transfer, userID: userID)
        let fetched = try await actor.fetchTransactions(userID: userID, currency: currency).first

        #expect(fetched?.kind == .transfer)
        #expect(fetched?.destinationAccountID == destination)
        #expect(fetched?.category == nil)
    }

    // MARK: - User isolation

    @Test func fetchOnlyReturnsRecordsForTheRequestedUser() async throws {
        let actor = makeActor()
        let otherUserID = UUID()

        try await actor.upsertAccount(makeAccount(name: "Mine"), userID: userID)
        try await actor.upsertAccount(makeAccount(name: "Not Mine"), userID: otherUserID)

        let accounts = try await actor.fetchAccounts(userID: userID, currency: currency)

        #expect(accounts.map(\.name) == ["Mine"])
    }

    // MARK: - Full-cache reconciliation

    @Test func reconcileUpsertsNewAndUpdatesExistingAccounts() async throws {
        let actor = makeActor()
        let keepID = UUID()
        try await actor.upsertAccount(makeAccount(id: keepID, name: "Old Name"), userID: userID)

        let updatedKeep = makeAccount(id: keepID, name: "Updated Name")
        let brandNew = makeAccount(name: "Brand New")
        try await actor.reconcileAccounts([updatedKeep, brandNew], userID: userID)

        let accounts = try await actor.fetchAccounts(userID: userID, currency: currency)
        #expect(Set(accounts.map(\.name)) == ["Updated Name", "Brand New"])
    }

    @Test func reconcileRemovesLocalRecordsMissingFromTheAuthoritativeSet() async throws {
        let actor = makeActor()
        let staleID = UUID()
        try await actor.upsertAccount(makeAccount(id: staleID, name: "Deleted Remotely"), userID: userID)

        try await actor.reconcileAccounts([], userID: userID)

        let accounts = try await actor.fetchAccounts(userID: userID, currency: currency)
        #expect(accounts.isEmpty)
    }

    @Test func reconcileDoesNotAffectOtherUsersRecords() async throws {
        let actor = makeActor()
        let otherUserID = UUID()
        try await actor.upsertAccount(makeAccount(name: "Other User's Account"), userID: otherUserID)

        try await actor.reconcileAccounts([], userID: userID)

        let otherUsersAccounts = try await actor.fetchAccounts(userID: otherUserID, currency: currency)
        #expect(otherUsersAccounts.count == 1)
    }

    @Test func reconcileTransactionsRemovesStaleRecords() async throws {
        let actor = makeActor()
        let accountID = UUID()
        let stale = makeTransaction(source: accountID, date: try LocalDate(parsing: "2026-09-01"))
        try await actor.upsertTransaction(stale, userID: userID)

        let fresh = makeTransaction(source: accountID, date: try LocalDate(parsing: "2026-09-14"))
        try await actor.reconcileTransactions([fresh], userID: userID)

        let transactions = try await actor.fetchTransactions(userID: userID, currency: currency)
        #expect(transactions.map(\.id) == [fresh.id])
    }

    // MARK: - Cache metadata

    @Test func lastSuccessfulSyncIsNilBeforeFirstSync() async throws {
        let actor = makeActor()

        let syncedAt = try await actor.lastSuccessfulSync(userID: userID, resource: .accounts)

        #expect(syncedAt == nil)
    }

    @Test func markSyncedThenReadBackReturnsTheSameTimestamp() async throws {
        let actor = makeActor()
        let date = Date(timeIntervalSince1970: 1_800_000_000)

        try await actor.markSynced(userID: userID, resource: .transactions, at: date)
        let syncedAt = try await actor.lastSuccessfulSync(userID: userID, resource: .transactions)

        #expect(syncedAt == date)
    }

    @Test func markSyncedTwiceUpdatesRatherThanDuplicates() async throws {
        let actor = makeActor()
        try await actor.markSynced(userID: userID, resource: .accounts, at: Date(timeIntervalSince1970: 1))
        try await actor.markSynced(userID: userID, resource: .accounts, at: Date(timeIntervalSince1970: 2))

        let syncedAt = try await actor.lastSuccessfulSync(userID: userID, resource: .accounts)

        #expect(syncedAt == Date(timeIntervalSince1970: 2))
    }

    // MARK: - User data isolation on identity change

    @Test func clearAllDataRemovesEverythingForThatUserOnly() async throws {
        let actor = makeActor()
        let otherUserID = UUID()

        try await actor.upsertWalletProfile(WalletProfile(baseCurrency: currency), userID: userID)
        try await actor.upsertAccount(makeAccount(), userID: userID)
        try await actor.upsertTransaction(
            makeTransaction(source: UUID(), date: try LocalDate(parsing: "2026-09-14")),
            userID: userID
        )
        try await actor.markSynced(userID: userID, resource: .accounts)

        try await actor.upsertWalletProfile(WalletProfile(baseCurrency: currency), userID: otherUserID)

        try await actor.clearAllData(userID: userID)

        #expect(try await actor.fetchWalletProfile(userID: userID) == nil)
        #expect(try await actor.fetchAccounts(userID: userID, currency: currency).isEmpty)
        #expect(try await actor.fetchTransactions(userID: userID, currency: currency).isEmpty)
        #expect(try await actor.lastSuccessfulSync(userID: userID, resource: .accounts) == nil)
        #expect(try await actor.fetchWalletProfile(userID: otherUserID) != nil)
    }

    // MARK: - Corrupted records

    @Test func corruptedAccountKindRawValueThrowsRatherThanCrashing() async throws {
        let container = PersistenceContainer.makeInMemory()
        let actor = PersistenceActor(modelContainer: container)

        // Insert a record with an invalid raw value directly via a second
        // handle onto the same in-memory container, bypassing the domain
        // mapping that would normally prevent this.
        let context = ModelContext(container)
        context.insert(
            AccountRecord(
                id: UUID(),
                userID: userID,
                name: "Corrupt",
                kindRawValue: "not_a_real_kind",
                openingBalanceMinor: 0,
                isArchived: false,
                archivedAt: nil,
                createdAt: Date(),
                updatedAt: Date()
            )
        )
        try context.save()

        await #expect(throws: PersistenceError.corruptedRecord) {
            try await actor.fetchAccounts(userID: userID, currency: currency)
        }
    }
}
