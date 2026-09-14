import Foundation
import Testing
@testable import pocketledger

struct AnalyticsCalculatorTests {
    private let currency = CurrencyCode(rawValue: "TRY")!
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let today = try! LocalDate(parsing: "2026-09-14")

    private func transaction(
        kind: TransactionKind,
        source: UUID = UUID(),
        destination: UUID? = nil,
        amountMinor: Int64,
        category: TransactionCategory? = nil,
        date: String
    ) -> Transaction {
        Transaction(
            id: UUID(), kind: kind, sourceAccountID: source, destinationAccountID: destination,
            amount: Money(minorUnits: amountMinor, currency: currency), category: category,
            title: "T", note: nil, date: try! LocalDate(parsing: date), createdAt: now, updatedAt: now
        )
    }

    private func calculate(_ transactions: [Transaction], monthsToInclude: Int = 4) throws -> AnalyticsSnapshot {
        try AnalyticsCalculator.calculate(
            transactions: transactions, currency: currency, monthsToInclude: monthsToInclude, today: today
        )
    }

    @Test func monthlySpendingIsOrderedOldestFirstAndCoversTheRequestedMonthCount() throws {
        let snapshot = try calculate([], monthsToInclude: 4)

        #expect(snapshot.monthlySpending.map(\.month) == [
            CalendarMonth(year: 2026, month: 6),
            CalendarMonth(year: 2026, month: 7),
            CalendarMonth(year: 2026, month: 8),
            CalendarMonth(year: 2026, month: 9),
        ])
    }

    @Test func noTransactionsProducesAllZeroMonthsRatherThanCrashing() throws {
        let snapshot = try calculate([])

        #expect(snapshot.monthlySpending.allSatisfy { $0.expense.isZero })
        #expect(snapshot.categoryDistribution.isEmpty)
    }

    @Test func onlyIncomeProducesZeroExpenseAndEmptyCategoryDistribution() throws {
        let snapshot = try calculate([
            transaction(kind: .income, amountMinor: 500_000, date: "2026-09-01"),
        ])

        #expect(snapshot.monthlySpending.last?.expense.isZero == true)
        #expect(snapshot.categoryDistribution.isEmpty)
        #expect(snapshot.incomeExpenseTrend.last?.income.minorUnits == 500_000)
    }

    @Test func onlyExpensesProduceZeroIncomeInTheTrend() throws {
        let snapshot = try calculate([
            transaction(kind: .expense, amountMinor: 5_000, category: .food, date: "2026-09-01"),
        ])

        #expect(snapshot.incomeExpenseTrend.last?.income.isZero == true)
        #expect(snapshot.incomeExpenseTrend.last?.expense.minorUnits == 5_000)
    }

    @Test func transfersAreExcludedFromEveryVisualization() throws {
        let sourceID = UUID()
        let destinationID = UUID()
        let snapshot = try calculate([
            transaction(kind: .transfer, source: sourceID, destination: destinationID, amountMinor: 100_000, date: "2026-09-05"),
        ])

        #expect(snapshot.monthlySpending.last?.expense.isZero == true)
        #expect(snapshot.incomeExpenseTrend.last?.income.isZero == true)
        #expect(snapshot.incomeExpenseTrend.last?.expense.isZero == true)
        #expect(snapshot.categoryDistribution.isEmpty)
    }

    @Test func categoryDistributionGroupsAndComputesPercentagesForTheCurrentMonth() throws {
        let snapshot = try calculate([
            transaction(kind: .expense, amountMinor: 7_500, category: .food, date: "2026-09-01"),
            transaction(kind: .expense, amountMinor: 2_500, category: .transport, date: "2026-09-02"),
        ])

        let food = try #require(snapshot.categoryDistribution.first { $0.category == .food })
        let transport = try #require(snapshot.categoryDistribution.first { $0.category == .transport })

        #expect(food.percentage == 75)
        #expect(transport.percentage == 25)
    }

    @Test func categoryDistributionIsSortedByAmountDescending() throws {
        let snapshot = try calculate([
            transaction(kind: .expense, amountMinor: 1_000, category: .entertainment, date: "2026-09-01"),
            transaction(kind: .expense, amountMinor: 9_000, category: .bills, date: "2026-09-02"),
        ])

        #expect(snapshot.categoryDistribution.map(\.category) == [.bills, .entertainment])
    }

    @Test func categoryDistributionOnlyReflectsTheCurrentMonth() throws {
        let snapshot = try calculate([
            transaction(kind: .expense, amountMinor: 5_000, category: .food, date: "2026-08-01"),
        ])

        #expect(snapshot.categoryDistribution.isEmpty)
    }

    @Test func transactionsOutsideTheRequestedMonthWindowAreIgnored() throws {
        let snapshot = try calculate([
            transaction(kind: .expense, amountMinor: 5_000, category: .food, date: "2025-01-01"),
        ])

        #expect(snapshot.monthlySpending.allSatisfy { $0.expense.isZero })
    }

    @Test func decemberToJanuaryYearBoundaryIsHandledCorrectly() throws {
        let januaryToday = try LocalDate(parsing: "2026-01-14")
        let snapshot = try AnalyticsCalculator.calculate(
            transactions: [
                transaction(kind: .expense, amountMinor: 5_000, category: .food, date: "2025-12-15"),
            ],
            currency: currency,
            monthsToInclude: 2,
            today: januaryToday
        )

        #expect(snapshot.monthlySpending.map(\.month) == [
            CalendarMonth(year: 2025, month: 12),
            CalendarMonth(year: 2026, month: 1),
        ])
        #expect(snapshot.monthlySpending.first?.expense.minorUnits == 5_000)
    }

    @Test func editingATransactionAmountChangesTheCalculatedTotal() throws {
        let id = UUID()
        let original = Transaction(
            id: id, kind: .expense, sourceAccountID: UUID(), destinationAccountID: nil,
            amount: Money(minorUnits: 5_000, currency: currency), category: .food,
            title: "T", note: nil, date: today, createdAt: now, updatedAt: now
        )
        let edited = Transaction(
            id: id, kind: .expense, sourceAccountID: original.sourceAccountID, destinationAccountID: nil,
            amount: Money(minorUnits: 9_000, currency: currency), category: .food,
            title: "T", note: nil, date: today, createdAt: now, updatedAt: now
        )

        let before = try calculate([original])
        let after = try calculate([edited])

        #expect(before.monthlySpending.last?.expense.minorUnits == 5_000)
        #expect(after.monthlySpending.last?.expense.minorUnits == 9_000)
    }
}
