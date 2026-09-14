import Foundation

protocol TransactionLocalStore: Sendable {
    func fetchAll(userID: UUID, currency: CurrencyCode) async throws -> [Transaction]
    func upsert(_ transaction: Transaction, userID: UUID) async throws
    func delete(id: UUID) async throws
    func reconcile(_ transactions: [Transaction], userID: UUID) async throws
}

struct DefaultTransactionLocalStore: TransactionLocalStore {
    private let persistenceActor: PersistenceActor

    init(persistenceActor: PersistenceActor) {
        self.persistenceActor = persistenceActor
    }

    func fetchAll(userID: UUID, currency: CurrencyCode) async throws -> [Transaction] {
        try await persistenceActor.fetchTransactions(userID: userID, currency: currency)
    }

    func upsert(_ transaction: Transaction, userID: UUID) async throws {
        try await persistenceActor.upsertTransaction(transaction, userID: userID)
    }

    func delete(id: UUID) async throws {
        try await persistenceActor.deleteTransaction(id: id)
    }

    func reconcile(_ transactions: [Transaction], userID: UUID) async throws {
        try await persistenceActor.reconcileTransactions(transactions, userID: userID)
    }
}
