import Foundation

/// `LocalDate` deliberately has no `Date`/timezone semantics (see its own
/// doc comment) — these conversions exist only so a SwiftUI `DatePicker`
/// (which binds to `Date`) can present/edit one. Presentation-layer-only;
/// Domain code never uses this.
extension LocalDate {
    init(date: Date, calendar: Calendar = .current) {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        self = (try? LocalDate(year: components.year!, month: components.month!, day: components.day!))
            ?? .today(calendar: calendar)
    }

    func asDate(calendar: Calendar = .current) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? Date()
    }
}
