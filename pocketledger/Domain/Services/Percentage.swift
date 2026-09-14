import Foundation

/// Percentage math shared across Dashboard (month-over-month comparison),
/// Analytics (category share of total spending) and — in a later phase —
/// `SpendingInsightEngine`, so the rounding behavior and division-by-zero
/// handling lives in exactly one place.
enum Percentage {
    /// `nil` when there's no meaningful previous value to compare against
    /// (zero, or a different currency) — callers must never show a
    /// misleading 0%/∞% change (see the PRD's insight-quality rules).
    static func changeFrom(previous: Money, to current: Money) -> Int? {
        guard !previous.isZero, current.currency == previous.currency else { return nil }
        let percent = ((current.decimalValue - previous.decimalValue) / previous.decimalValue) * 100
        return roundedInt(percent)
    }

    /// What percentage `part` is of `total` — e.g. one category's spending
    /// as a share of the month's total spending.
    static func shareOfTotal(part: Money, total: Money) -> Int? {
        guard !total.isZero, part.currency == total.currency else { return nil }
        let percent = (part.decimalValue / total.decimalValue) * 100
        return roundedInt(percent)
    }

    /// `Decimal` division can produce ~38 significant digits, and
    /// `NSDecimalNumber.intValue` silently returns 0 for a value with that
    /// much fractional precision (a real Foundation quirk, confirmed
    /// empirically: `NSDecimalNumber(decimal: Decimal(-405)/Decimal(839)*100
    /// ).intValue == 0`, despite the value being -48.27...). Rounding to a
    /// plain integer `Decimal` first avoids it.
    private static func roundedInt(_ decimal: Decimal) -> Int {
        var rounded = Decimal()
        var mutable = decimal
        NSDecimalRound(&rounded, &mutable, 0, .plain)
        return NSDecimalNumber(decimal: rounded).intValue
    }
}
