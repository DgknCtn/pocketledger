import Foundation

/// Backs the demo environment (PRD "Explore with Sample Data"): the exact
/// same `AccountRepository` protocol the real UI depends on, but backed by
/// in-memory sample data instead of Supabase — so Features/ViewModels never
/// need a `if demoMode` branch (see the Architecture specification's
/// "Why Demo Repository Instead of Special Cases Everywhere").
struct SampleAccountRepository: AccountRepository {
    private let store: SampleDataStore

    init(store: SampleDataStore) {
        self.store = store
    }

    func cachedAccounts() async throws -> [Account] {
        await store.allAccounts()
    }

    func refreshAccounts() async throws -> [Account] {
        await store.allAccounts()
    }

    func createAccount(_ input: CreateAccountInput) async throws -> Account {
        let now = Date()
        let account = Account(
            id: input.id,
            name: input.name,
            kind: input.kind,
            openingBalance: input.openingBalance,
            isArchived: false,
            archivedAt: nil,
            createdAt: now,
            updatedAt: now
        )
        await store.upsertAccount(account)
        return account
    }

    func updateAccount(_ input: UpdateAccountInput) async throws -> Account {
        guard let existing = await store.account(id: input.id) else {
            throw RepositoryError.notFound
        }
        let updated = Account(
            id: existing.id,
            name: input.name,
            kind: existing.kind,
            openingBalance: input.openingBalance,
            isArchived: existing.isArchived,
            archivedAt: existing.archivedAt,
            createdAt: existing.createdAt,
            updatedAt: Date()
        )
        await store.upsertAccount(updated)
        return updated
    }

    func archiveAccount(id: Account.ID) async throws -> Account {
        guard let existing = await store.account(id: id) else {
            throw RepositoryError.notFound
        }
        let archived = Account(
            id: existing.id,
            name: existing.name,
            kind: existing.kind,
            openingBalance: existing.openingBalance,
            isArchived: true,
            archivedAt: Date(),
            createdAt: existing.createdAt,
            updatedAt: Date()
        )
        await store.upsertAccount(archived)
        return archived
    }

    func deleteAccount(id: Account.ID) async throws {
        try await store.deleteAccount(id: id)
    }
}
