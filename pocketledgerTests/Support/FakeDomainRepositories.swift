import Foundation
import os
@testable import pocketledger

/// Protocol-level fakes for `AccountRepository`/`TransactionRepository`
/// themselves — one layer above the `Fake*RemoteDataSource`/
/// `Fake*LocalStore` pairs used to test the `Default*Repository`
/// implementations. UseCase and ViewModel tests use these so they exercise
/// only their own logic, not the repository's cache/remote coordination
/// (already covered by `AccountRepositoryTests`/`TransactionRepositoryTests`).
final class FakeAccountRepository: AccountRepository, @unchecked Sendable {
    private let state = OSAllocatedUnfairLock<[UUID: Account]>(initialState: [:])
    var cachedResult: [Account] = []
    var refreshResult: [Account] = []
    var refreshError: Error?
    var createError: Error?
    var archiveError: Error?
    var deleteError: Error?
    private(set) var deletedIDs: [UUID] = []
    private(set) var archivedIDs: [UUID] = []

    func seed(_ account: Account) {
        state.withLock { $0[account.id] = account }
    }

    func cachedAccounts() async throws -> [Account] { cachedResult }

    func refreshAccounts() async throws -> [Account] {
        if let refreshError { throw refreshError }
        return refreshResult
    }

    func createAccount(_ input: CreateAccountInput) async throws -> Account {
        if let createError { throw createError }
        let now = Date()
        let account = Account(
            id: input.id, name: input.name, kind: input.kind, openingBalance: input.openingBalance,
            isArchived: false, archivedAt: nil, createdAt: now, updatedAt: now
        )
        state.withLock { $0[account.id] = account }
        return account
    }

    func updateAccount(_ input: UpdateAccountInput) async throws -> Account {
        guard let existing = state.withLock({ $0[input.id] }) else { throw RepositoryError.notFound }
        let updated = Account(
            id: existing.id, name: input.name, kind: existing.kind, openingBalance: input.openingBalance,
            isArchived: existing.isArchived, archivedAt: existing.archivedAt,
            createdAt: existing.createdAt, updatedAt: Date()
        )
        state.withLock { $0[updated.id] = updated }
        return updated
    }

    func archiveAccount(id: Account.ID) async throws -> Account {
        if let archiveError { throw archiveError }
        archivedIDs.append(id)
        guard let existing = state.withLock({ $0[id] }) else { throw RepositoryError.notFound }
        let archived = Account(
            id: existing.id, name: existing.name, kind: existing.kind, openingBalance: existing.openingBalance,
            isArchived: true, archivedAt: Date(), createdAt: existing.createdAt, updatedAt: Date()
        )
        state.withLock { $0[archived.id] = archived }
        return archived
    }

    func deleteAccount(id: Account.ID) async throws {
        if let deleteError { throw deleteError }
        deletedIDs.append(id)
        state.withLock { $0[id] = nil }
    }
}

final class FakeTransactionRepository: TransactionRepository, @unchecked Sendable {
    var cachedResult: [Transaction] = []
    var refreshResult: [Transaction] = []
    var refreshError: Error?

    func cachedTransactions() async throws -> [Transaction] { cachedResult }

    func refreshTransactions() async throws -> [Transaction] {
        if let refreshError { throw refreshError }
        return refreshResult
    }

    func createTransaction(_ input: NewTransaction) async throws -> Transaction {
        Transaction(
            id: input.id, kind: input.kind, sourceAccountID: input.sourceAccountID,
            destinationAccountID: input.destinationAccountID, amount: input.amount, category: input.category,
            title: input.title, note: input.note, date: input.date, createdAt: Date(), updatedAt: Date()
        )
    }

    func updateTransaction(id: Transaction.ID, input: NewTransaction) async throws -> Transaction {
        Transaction(
            id: id, kind: input.kind, sourceAccountID: input.sourceAccountID,
            destinationAccountID: input.destinationAccountID, amount: input.amount, category: input.category,
            title: input.title, note: input.note, date: input.date, createdAt: Date(), updatedAt: Date()
        )
    }

    func deleteTransaction(id: Transaction.ID) async throws {}
}

final class FakeWalletProfileRepository: WalletProfileRepository, @unchecked Sendable {
    var cached: WalletProfile?
    var refreshed: WalletProfile?

    func cachedProfile() async throws -> WalletProfile? { cached }
    func refreshProfile() async throws -> WalletProfile? { refreshed }
    func createProfile(baseCurrency: CurrencyCode) async throws -> WalletProfile {
        let profile = WalletProfile(baseCurrency: baseCurrency)
        cached = profile
        return profile
    }
}
