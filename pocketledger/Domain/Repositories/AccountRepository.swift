import Foundation

/// User input for creating a new `Account`.
///
/// `id` is client-generated (see `NewTransaction`'s doc comment for why),
/// and there is no `currentBalance` field — only `openingBalance` is ever
/// written; current balance is always derived.
struct CreateAccountInput: Sendable {
    let id: UUID
    let name: String
    let kind: AccountKind
    let openingBalance: Money
}

/// User input for editing an existing `Account`'s editable fields.
struct UpdateAccountInput: Sendable {
    let id: UUID
    let name: String
    let openingBalance: Money
}

/// Domain-owned boundary for reading and mutating `Account`s.
///
/// Read operations are split into `cached`/`refresh` pairs to make the
/// cache-first, stale-while-revalidate read strategy explicit at the call
/// site (see the Architecture specification) — a concrete implementation
/// coordinating a remote data source and a local cache is added once
/// Networking and SwiftData exist.
protocol AccountRepository: Sendable {
    func cachedAccounts() async throws -> [Account]
    func refreshAccounts() async throws -> [Account]

    func createAccount(_ input: CreateAccountInput) async throws -> Account
    func updateAccount(_ input: UpdateAccountInput) async throws -> Account
    func archiveAccount(id: Account.ID) async throws -> Account
    func deleteAccount(id: Account.ID) async throws
}
