/// A presentation-facing read model pairing an `Account` with its derived
/// current balance.
///
/// This is not a persisted entity — it is produced on demand (by a future
/// use case, via `AccountBalanceCalculator`) so Dashboard/Account screens
/// never need to recompute balance logic themselves.
struct AccountSummary: Equatable, Sendable {
    let account: Account
    let currentBalance: Money
}
