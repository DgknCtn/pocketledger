import Foundation

/// Domain-owned boundary for reading and mutating `Transaction`s.
///
/// `updateTransaction` takes a full `NewTransaction` payload (not a partial
/// patch) because a transaction's fields carry cross-field invariants
/// (e.g. changing `kind` to `.transfer` requires a destination account and
/// forbids a category) — sending the complete intended state keeps those
/// invariants readable at the call site instead of split across partial
/// updates. A concrete implementation is added once Networking and
/// SwiftData exist.
protocol TransactionRepository: Sendable {
    func cachedTransactions() async throws -> [Transaction]
    func refreshTransactions() async throws -> [Transaction]

    func createTransaction(_ input: NewTransaction) async throws -> Transaction
    func updateTransaction(id: Transaction.ID, input: NewTransaction) async throws -> Transaction
    func deleteTransaction(id: Transaction.ID) async throws
}
