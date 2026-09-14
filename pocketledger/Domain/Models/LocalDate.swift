import Foundation

/// A calendar date (year/month/day) with no time-of-day or timezone
/// component.
///
/// Transaction dates are "which day did this happen on", not an instant in
/// time — converting them to a `Date`/timestamp risks a transaction shifting
/// to a different calendar day across timezones. `LocalDate` mirrors the
/// remote `transaction_date` PostgreSQL `date` column and its `YYYY-MM-DD`
/// wire format exactly.
struct LocalDate: Hashable, Sendable {
    enum ParsingError: Error, Equatable, Sendable {
        case invalidFormat(String)
        case invalidCalendarDate(String)
    }

    let year: Int
    let month: Int
    let day: Int

    init(year: Int, month: Int, day: Int) throws {
        guard Self.isValidCalendarDate(year: year, month: month, day: day) else {
            throw ParsingError.invalidCalendarDate(
                String(format: "%04d-%02d-%02d", year, month, day)
            )
        }
        self.year = year
        self.month = month
        self.day = day
    }

    /// Parses a `"YYYY-MM-DD"` string, as produced by PostgreSQL/PostgREST.
    init(parsing string: String) throws {
        let components = string.split(separator: "-", omittingEmptySubsequences: false)
        guard
            components.count == 3,
            components[0].count == 4, let year = Int(components[0]),
            components[1].count == 2, let month = Int(components[1]),
            components[2].count == 2, let day = Int(components[2])
        else {
            throw ParsingError.invalidFormat(string)
        }

        try self.init(year: year, month: month, day: day)
    }

    /// The canonical `"YYYY-MM-DD"` wire representation.
    var isoString: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    private static func isValidCalendarDate(year: Int, month: Int, day: Int) -> Bool {
        guard (1...9999).contains(year), (1...12).contains(month), day >= 1 else {
            return false
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt

        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day

        guard let date = calendar.date(from: components) else { return false }

        // Guards against Calendar silently rolling an out-of-range day
        // (e.g. day 31 in a 30-day month) into the next month.
        let resolved = calendar.dateComponents([.year, .month, .day], from: date)
        return resolved.year == year && resolved.month == month && resolved.day == day
    }

    /// Today's calendar date in the given `Calendar`'s time zone.
    static func today(calendar: Calendar = .current) -> LocalDate {
        let components = calendar.dateComponents([.year, .month, .day], from: Date())
        // Components sourced from a real `Date` are always a valid calendar date.
        return try! LocalDate(
            year: components.year!,
            month: components.month!,
            day: components.day!
        )
    }
}

extension LocalDate: Comparable {
    static func < (lhs: LocalDate, rhs: LocalDate) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }
}

extension LocalDate: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        do {
            try self.init(parsing: string)
        } catch {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid LocalDate string: \(string)"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(isoString)
    }
}
