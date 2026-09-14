/// Turns raw transactions into the three visualizations the Analytics
/// screen needs. Pure, deterministic and platform-independent — no
/// SwiftUI, no Swift Charts (see the Architecture specification).
/// Internal transfers are excluded throughout, same as the Dashboard.
enum AnalyticsCalculator {
    static func calculate(
        transactions: [Transaction],
        currency: CurrencyCode,
        monthsToInclude: Int = 4,
        today: LocalDate = .today()
    ) throws -> AnalyticsSnapshot {
        let months = orderedMonths(endingAt: CalendarMonth(date: today), count: monthsToInclude)

        var monthlySpending: [MonthlySpendingPoint] = []
        var incomeExpenseTrend: [IncomeExpensePoint] = []

        for month in months {
            let monthTransactions = transactions.filter { month.contains($0.date) }
            let expense = try Money.sum(
                monthTransactions.filter { $0.kind == .expense }.map(\.amount),
                currency: currency
            )
            let income = try Money.sum(
                monthTransactions.filter { $0.kind == .income }.map(\.amount),
                currency: currency
            )
            monthlySpending.append(MonthlySpendingPoint(month: month, expense: expense))
            incomeExpenseTrend.append(IncomeExpensePoint(month: month, income: income, expense: expense))
        }

        let currentMonth = CalendarMonth(date: today)
        let currentMonthExpenses = transactions.filter { $0.kind == .expense && currentMonth.contains($0.date) }
        let totalExpense = try Money.sum(currentMonthExpenses.map(\.amount), currency: currency)

        var categoryDistribution: [CategorySpending] = []
        for category in TransactionCategory.allCases {
            let categoryAmount = try Money.sum(
                currentMonthExpenses.filter { $0.category == category }.map(\.amount),
                currency: currency
            )
            guard !categoryAmount.isZero else { continue }
            categoryDistribution.append(
                CategorySpending(
                    category: category,
                    amount: categoryAmount,
                    percentage: Percentage.shareOfTotal(part: categoryAmount, total: totalExpense)
                )
            )
        }
        categoryDistribution.sort { $0.amount.minorUnits > $1.amount.minorUnits }

        return AnalyticsSnapshot(
            monthlySpending: monthlySpending,
            categoryDistribution: categoryDistribution,
            incomeExpenseTrend: incomeExpenseTrend
        )
    }

    /// Oldest-first, ending at `end` — the order charts want (left to
    /// right, chronological).
    private static func orderedMonths(endingAt end: CalendarMonth, count: Int) -> [CalendarMonth] {
        var months: [CalendarMonth] = []
        var month = end
        for _ in 0..<count {
            months.append(month)
            month = month.previous
        }
        return Array(months.reversed())
    }
}
