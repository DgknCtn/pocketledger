import Foundation

/// A financial container the user manually tracks (bank account, cash
/// wallet, or credit card) — never a real connected bank account.
///
/// `Account` deliberately has no `currentBalance` field: balance is a
/// derived value, computed by `AccountBalanceCalculator` from
/// `openingBalance` plus the account's transactions. Storing a second,
/// independently-updated balance field would create a second source of
/// truth that can drift out of sync with the transaction history.
struct Account: Identifiable, Equatable, Sendable {
    let id: UUID
    let name: String
    let kind: AccountKind
    let openingBalance: Money
    let isArchived: Bool
    let createdAt: Date
    let updatedAt: Date
}
