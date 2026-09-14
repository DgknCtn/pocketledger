import Foundation

/// The `LocalStore` layer between a (future) `Repository` and
/// `PersistenceActor`. It exists as its own protocol — separate from
/// `PersistenceActor` — so repository tests can depend on an in-memory fake
/// instead of real SwiftData (see `FakeWalletProfileLocalStore`).
protocol WalletProfileLocalStore: Sendable {
    func fetch(userID: UUID) async throws -> WalletProfile?
    func upsert(_ profile: WalletProfile, userID: UUID) async throws
}

struct DefaultWalletProfileLocalStore: WalletProfileLocalStore {
    private let persistenceActor: PersistenceActor

    init(persistenceActor: PersistenceActor) {
        self.persistenceActor = persistenceActor
    }

    func fetch(userID: UUID) async throws -> WalletProfile? {
        try await persistenceActor.fetchWalletProfile(userID: userID)
    }

    func upsert(_ profile: WalletProfile, userID: UUID) async throws {
        try await persistenceActor.upsertWalletProfile(profile, userID: userID)
    }
}
