struct MonthlySpendingPoint: Equatable, Sendable, Identifiable {
    let month: CalendarMonth
    let expense: Money
    var id: CalendarMonth { month }
}

struct CategorySpending: Equatable, Sendable, Identifiable {
    let category: TransactionCategory
    let amount: Money
    /// `nil` only when the month's total expense is zero — see the PRD's
    /// insight-quality rules against showing a misleading percentage.
    let percentage: Int?
    var id: TransactionCategory { category }
}

struct IncomeExpensePoint: Equatable, Sendable, Identifiable {
    let month: CalendarMonth
    let income: Money
    let expense: Money
    var id: CalendarMonth { month }
}

/// A read model assembled by `AnalyticsCalculator` — not persisted (see the
/// Architecture specification's "Analytics Does Not Persist Derived Data").
struct AnalyticsSnapshot: Equatable, Sendable {
    let monthlySpending: [MonthlySpendingPoint]
    let categoryDistribution: [CategorySpending]
    let incomeExpenseTrend: [IncomeExpensePoint]
}
