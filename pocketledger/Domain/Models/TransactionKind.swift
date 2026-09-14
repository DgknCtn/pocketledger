/// The three movement types a `Transaction` can represent.
///
/// `transfer` is money moving between two of the user's own accounts (e.g.
/// paying a credit card from a bank account) — it is neither income nor
/// expense, and is excluded from analytics/spending totals to avoid
/// double-counting the user's own money moving between their own accounts.
enum TransactionKind: String, Sendable, CaseIterable, Codable {
    case income
    case expense
    case transfer
}
