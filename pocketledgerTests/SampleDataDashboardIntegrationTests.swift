import Foundation
import Testing
@testable import pocketledger

/// Exercises `LoadDashboardUseCase`'s monthly aggregation against the
/// *real* `SampleDataFactory` output rather than hand-rolled fixtures —
/// this is what actually caught the `NSDecimalNumber.intValue` precision
/// bug described in `Percentage`: every other test used round,
/// low-precision fixture amounts that happened not to trigger it.
struct SampleDataDashboardIntegrationTests {
    @Test func currentAndPreviousMonthExpenseTotalsMatchTheGeneratedFixtures() async throws {
        let transactions = SampleDataFactory.transactions()
        let today = LocalDate.today()
        let currentMonth = CalendarMonth(date: today)
        let previousMonth = currentMonth.previous

        let currentTotal = transactions
            .filter { $0.kind == .expense && currentMonth.contains($0.date) }
            .reduce(Int64(0)) { $0 + $1.amount.minorUnits }
        let previousTotal = transactions
            .filter { $0.kind == .expense && previousMonth.contains($0.date) }
            .reduce(Int64(0)) { $0 + $1.amount.minorUnits }

        // The two months are meaningfully different (SampleDataFactory
        // adds a variance to earlier months) — if this ever becomes equal,
        // Dashboard's month-over-month comparison silently stops being a
        // meaningful demo.
        #expect(currentTotal != previousTotal)
        #expect(previousTotal > 0)
    }

    @Test func loadDashboardUseCaseAgainstRealSampleDataProducesANonZeroComparison() async throws {
        let store = SampleDataStore()
        let useCase = LoadDashboardUseCase(
            accountRepository: SampleAccountRepository(store: store),
            transactionRepository: SampleTransactionRepository(store: store),
            walletProfileRepository: SampleWalletProfileRepository(store: store)
        )

        let snapshot = try await useCase.refresh()

        let previousExpense = try #require(snapshot.previousMonthExpense)
        let percent = try #require(Percentage.changeFrom(previous: previousExpense, to: snapshot.monthlyExpense))
        #expect(percent != 0)
    }
}
