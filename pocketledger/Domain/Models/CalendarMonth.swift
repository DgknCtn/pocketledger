/// A specific calendar month (e.g. September 2026), used to group
/// transactions for Dashboard/Analytics without reaching for `Calendar`/
/// `Date` — `LocalDate.year`/`.month` are already plain integers, so month
/// arithmetic is just integer arithmetic. "September transactions" means
/// this, not "the last 30 days" (see the Architecture specification's
/// "Date and Time Boundaries").
struct CalendarMonth: Hashable, Sendable {
    let year: Int
    let month: Int

    init(year: Int, month: Int) {
        self.year = year
        self.month = month
    }

    init(date: LocalDate) {
        year = date.year
        month = date.month
    }

    static func current(today: LocalDate = .today()) -> CalendarMonth {
        CalendarMonth(date: today)
    }

    var previous: CalendarMonth {
        month == 1 ? CalendarMonth(year: year - 1, month: 12) : CalendarMonth(year: year, month: month - 1)
    }

    func contains(_ date: LocalDate) -> Bool {
        date.year == year && date.month == month
    }
}

extension CalendarMonth: Comparable {
    static func < (lhs: CalendarMonth, rhs: CalendarMonth) -> Bool {
        (lhs.year, lhs.month) < (rhs.year, rhs.month)
    }
}
