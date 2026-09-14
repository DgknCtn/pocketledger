import Foundation

protocol AccountLocalStore: Sendable {
    func fetchAll(userID: UUID, currency: CurrencyCode) async throws -> [Account]
    func upsert(_ account: Account, userID: UUID) async throws
    func delete(id: UUID) async throws
    func reconcile(_ accounts: [Account], userID: UUID) async throws
}

struct DefaultAccountLocalStore: AccountLocalStore {
    private let persistenceActor: PersistenceActor

    init(persistenceActor: PersistenceActor) {
        self.persistenceActor = persistenceActor
    }

    func fetchAll(userID: UUID, currency: CurrencyCode) async throws -> [Account] {
        try await persistenceActor.fetchAccounts(userID: userID, currency: currency)
    }

    func upsert(_ account: Account, userID: UUID) async throws {
        try await persistenceActor.upsertAccount(account, userID: userID)
    }

    func delete(id: UUID) async throws {
        try await persistenceActor.deleteAccount(id: id)
    }

    func reconcile(_ accounts: [Account], userID: UUID) async throws {
        try await persistenceActor.reconcileAccounts(accounts, userID: userID)
    }
}
