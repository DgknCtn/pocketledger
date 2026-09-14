import Foundation
import os
@testable import pocketledger

/// In-memory `AccountLocalStore` used by repository tests so those tests
/// never touch real SwiftData. `failUpsert`/`failFetch` let a test simulate
/// "remote succeeded, local cache write failed" without needing a second,
/// SwiftData-backed test double.
final class FakeAccountLocalStore: AccountLocalStore, @unchecked Sendable {
    private let storage = OSAllocatedUnfairLock<[UUID: Account]>(initialState: [:])
    var failUpsert = false
    var failFetch = false

    func fetchAll(userID: UUID, currency: CurrencyCode) async throws -> [Account] {
        if failFetch { throw PersistenceError.fetchFailed }
        return storage.withLock { Array($0.values) }
    }

    func upsert(_ account: Account, userID: UUID) async throws {
        if failUpsert { throw PersistenceError.saveFailed }
        storage.withLock { $0[account.id] = account }
    }

    func delete(id: UUID) async throws {
        storage.withLock { $0[id] = nil }
    }

    func reconcile(_ accounts: [Account], userID: UUID) async throws {
        storage.withLock { $0 = Dictionary(uniqueKeysWithValues: accounts.map { ($0.id, $0) }) }
    }

    func seed(_ account: Account) {
        storage.withLock { $0[account.id] = account }
    }
}

final class FakeTransactionLocalStore: TransactionLocalStore, @unchecked Sendable {
    private let storage = OSAllocatedUnfairLock<[UUID: Transaction]>(initialState: [:])
    var failUpsert = false
    var failFetch = false

    func fetchAll(userID: UUID, currency: CurrencyCode) async throws -> [Transaction] {
        if failFetch { throw PersistenceError.fetchFailed }
        return storage.withLock { Array($0.values) }
    }

    func upsert(_ transaction: Transaction, userID: UUID) async throws {
        if failUpsert { throw PersistenceError.saveFailed }
        storage.withLock { $0[transaction.id] = transaction }
    }

    func delete(id: UUID) async throws {
        storage.withLock { $0[id] = nil }
    }

    func reconcile(_ transactions: [Transaction], userID: UUID) async throws {
        storage.withLock { $0 = Dictionary(uniqueKeysWithValues: transactions.map { ($0.id, $0) }) }
    }

    func seed(_ transaction: Transaction) {
        storage.withLock { $0[transaction.id] = transaction }
    }
}

final class FakeWalletProfileLocalStore: WalletProfileLocalStore, @unchecked Sendable {
    private let storage = OSAllocatedUnfairLock<WalletProfile?>(initialState: nil)

    func fetch(userID: UUID) async throws -> WalletProfile? {
        storage.withLock { $0 }
    }

    func upsert(_ profile: WalletProfile, userID: UUID) async throws {
        storage.withLock { $0 = profile }
    }

    func seed(_ profile: WalletProfile) {
        storage.withLock { $0 = profile }
    }
}
