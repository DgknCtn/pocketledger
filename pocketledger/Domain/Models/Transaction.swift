import Foundation

/// A single financial movement: income into an account, an expense from an
/// account, or a transfer between two of the user's own accounts.
///
/// `amount` is always stored positive — direction is entirely determined by
/// `kind` (and, for transfers, by whether an account is the source or the
/// destination). This avoids representing the same fact ("this account lost
/// money") in two different places (a negative sign *and* a `kind` value).
struct Transaction: Identifiable, Equatable, Sendable {
    let id: UUID

    let kind: TransactionKind
    let sourceAccountID: UUID
    let destinationAccountID: UUID?

    let amount: Money
    let category: TransactionCategory?

    let title: String
    let note: String?

    let date: LocalDate

    let createdAt: Date
    let updatedAt: Date
}

/// The user-provided input for creating a new `Transaction`.
///
/// Distinct from `Transaction` itself because a new transaction has no
/// server-assigned `createdAt`/`updatedAt` yet, and its `id` is a
/// client-generated UUID chosen up front (so an ambiguous network failure
/// can be safely retried with the same identifier — see the API
/// specification's "safe retry pattern").
struct NewTransaction: Sendable {
    let id: UUID

    let kind: TransactionKind
    let sourceAccountID: UUID
    let destinationAccountID: UUID?

    let amount: Money
    let category: TransactionCategory?

    let title: String
    let note: String?

    let date: LocalDate
}
