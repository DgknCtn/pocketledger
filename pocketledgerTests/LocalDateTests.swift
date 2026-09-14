import Foundation
import Testing
@testable import pocketledger

struct LocalDateTests {
    @Test func parsesValidISODateString() throws {
        let date = try LocalDate(parsing: "2026-09-14")

        #expect(date.year == 2026)
        #expect(date.month == 9)
        #expect(date.day == 14)
    }

    @Test func roundTripsBackToTheSameString() throws {
        let date = try LocalDate(parsing: "2026-01-05")

        #expect(date.isoString == "2026-01-05")
    }

    @Test(arguments: [
        "2026-13-01",  // month out of range
        "2026-02-30",  // day does not exist in February
        "2026-00-10",  // month zero
        "2026-09-00",  // day zero
        "not-a-date",
        "2026-9-14",   // not zero-padded
        "2026/09/14",  // wrong separator
        "",
    ])
    func rejectsInvalidDateStrings(invalid: String) {
        #expect(throws: (any Error).self) {
            try LocalDate(parsing: invalid)
        }
    }

    @Test func comparisonOrdersChronologically() throws {
        let earlier = try LocalDate(parsing: "2026-08-31")
        let later = try LocalDate(parsing: "2026-09-01")

        #expect(earlier < later)
        #expect(!(later < earlier))
    }

    @Test func todayMatchesCalendarComponentsForAFixedCalendar() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!

        let today = LocalDate.today(calendar: calendar)
        let expected = calendar.dateComponents([.year, .month, .day], from: Date())

        #expect(today.year == expected.year)
        #expect(today.month == expected.month)
        #expect(today.day == expected.day)
    }
}
