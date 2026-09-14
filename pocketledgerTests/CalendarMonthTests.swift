import Testing
@testable import pocketledger

struct CalendarMonthTests {
    @Test func containsMatchesSameYearAndMonth() throws {
        let month = CalendarMonth(year: 2026, month: 9)

        #expect(month.contains(try LocalDate(parsing: "2026-09-01")))
        #expect(month.contains(try LocalDate(parsing: "2026-09-30")))
        #expect(!month.contains(try LocalDate(parsing: "2026-08-31")))
        #expect(!month.contains(try LocalDate(parsing: "2026-10-01")))
    }

    @Test func previousStepsBackOneMonthWithinTheSameYear() {
        let month = CalendarMonth(year: 2026, month: 9)

        #expect(month.previous == CalendarMonth(year: 2026, month: 8))
    }

    @Test func previousAcrossJanuaryRollsBackToDecemberOfThePriorYear() {
        let month = CalendarMonth(year: 2026, month: 1)

        #expect(month.previous == CalendarMonth(year: 2025, month: 12))
    }

    @Test func initFromLocalDateExtractsYearAndMonth() throws {
        let month = CalendarMonth(date: try LocalDate(parsing: "2026-03-14"))

        #expect(month == CalendarMonth(year: 2026, month: 3))
    }

    @Test func comparisonOrdersChronologically() {
        let earlier = CalendarMonth(year: 2026, month: 8)
        let later = CalendarMonth(year: 2026, month: 9)

        #expect(earlier < later)
    }
}
