import Foundation

/// Presentation-only formatting for `CalendarMonth` — Domain code never
/// formats for display (see the Architecture specification's "Money
/// Boundaries", which applies here too).
extension CalendarMonth {
    var shortLabel: String {
        var calendar = Calendar.current
        calendar.timeZone = .current
        let components = DateComponents(year: year, month: month, day: 1)
        guard let date = calendar.date(from: components) else { return "\(month)/\(year)" }

        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.dateFormat = "MMM"
        return formatter.string(from: date)
    }
}
