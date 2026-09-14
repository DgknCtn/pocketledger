/// A read model assembled by `LoadDashboardUseCase` — not a database
/// entity. Every field here is derived from accounts/transactions at
/// request time; none of it is persisted (see the Architecture
/// specification's "Analytics Does Not Persist Derived Data").
struct DashboardSnapshot: Equatable, Sendable {
    let totalBalance: Money
    let accountSummaries: [AccountSummary]
    let monthlyIncome: Money
    let monthlyExpense: Money
    /// `nil` when there is no prior-month expense data to compare
    /// against — the comparison is omitted rather than shown as a
    /// misleading 0%/∞% change.
    let previousMonthExpense: Money?
    let recentTransactions: [Transaction]
}
