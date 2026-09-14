import Foundation
import os
@testable import pocketledger

/// In-memory `AccountLocalStore` used by repository tests (Phase 5) so
/// those tests never touch real SwiftData.
final class FakeAccountLocalStore: AccountLocalStore, @unchecked Sendable {
    private let storage = OSAllocatedUnfairLock<[UUID: Account]>(initialState: [:])

    func fetchAll(userID: UUID, currency: CurrencyCode) async throws -> [Account] {
        storage.withLock { Array($0.values) }
    }

    func upsert(_ account: Account, userID: UUID) async throws {
        storage.withLock { $0[account.id] = account }
    }

    func delete(id: UUID) async throws {
        storage.withLock { $0[id] = nil }
    }

    func reconcile(_ accounts: [Account], userID: UUID) async throws {
        storage.withLock { $0 = Dictionary(uniqueKeysWithValues: accounts.map { ($0.id, $0) }) }
    }
}

final class FakeTransactionLocalStore: TransactionLocalStore, @unchecked Sendable {
    private let storage = OSAllocatedUnfairLock<[UUID: Transaction]>(initialState: [:])

    func fetchAll(userID: UUID, currency: CurrencyCode) async throws -> [Transaction] {
        storage.withLock { Array($0.values) }
    }

    func upsert(_ transaction: Transaction, userID: UUID) async throws {
        storage.withLock { $0[transaction.id] = transaction }
    }

    func delete(id: UUID) async throws {
        storage.withLock { $0[id] = nil }
    }

    func reconcile(_ transactions: [Transaction], userID: UUID) async throws {
        storage.withLock { $0 = Dictionary(uniqueKeysWithValues: transactions.map { ($0.id, $0) }) }
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
}
