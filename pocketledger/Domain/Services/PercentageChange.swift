import Foundation

/// Computes a rounded percentage change between two `Money` values — shared
/// by the Dashboard's month-over-month comparison and (in a later phase)
/// `SpendingInsightEngine`'s "up N% this month" insights, so the same
/// rounding behavior and division-by-zero handling exists in exactly one
/// place.
enum PercentageChange {
    /// `nil` when there's no meaningful previous value to compare against
    /// (zero, or a different currency) — callers must never show a
    /// misleading 0%/∞% change (see the PRD's insight-quality rules).
    static func compute(current: Money, previous: Money) -> Int? {
        guard !previous.isZero, current.currency == previous.currency else { return nil }

        let change = current.decimalValue - previous.decimalValue
        let percent = (change / previous.decimalValue) * 100

        // `Decimal` division can produce ~38 significant digits, and
        // `NSDecimalNumber.intValue` silently returns 0 for a value with
        // that much fractional precision (a real Foundation quirk,
        // confirmed empirically: NSDecimalNumber(decimal:
        // Decimal(-405)/Decimal(839)*100).intValue == 0, despite the value
        // being -48.27...). Rounding to a plain integer Decimal first
        // avoids it.
        var rounded = Decimal()
        var mutablePercent = percent
        NSDecimalRound(&rounded, &mutablePercent, 0, .plain)

        return NSDecimalNumber(decimal: rounded).intValue
    }
}
