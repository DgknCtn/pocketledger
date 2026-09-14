import Foundation

/// Converts between a user-typed decimal amount string (e.g. `"2450.00"`)
/// and `Money`'s minor-unit representation. This is Presentation-layer
/// formatting, not Domain logic — `Money` itself never parses strings (see
/// the Architecture specification's "Money Boundaries").
enum MoneyInput {
    static func parse(_ text: String, currency: CurrencyCode) -> Money? {
        let cleaned = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: "")
        guard !cleaned.isEmpty, let decimal = Decimal(string: cleaned), decimal >= 0 else {
            return nil
        }

        let handler = NSDecimalNumberHandler(
            roundingMode: .plain, scale: 0,
            raiseOnExactness: false, raiseOnOverflow: false, raiseOnUnderflow: false, raiseOnDivideByZero: false
        )
        let minorUnits = NSDecimalNumber(decimal: decimal * 100)
            .rounding(accordingToBehavior: handler)
            .int64Value

        return Money(minorUnits: minorUnits, currency: currency)
    }

    /// A plain, editable numeric string suitable for prefilling a text
    /// field — no currency symbol or grouping separators, and always a
    /// `.` decimal point regardless of device locale, matching what
    /// `parse(_:currency:)` (via `Decimal(string:)`) expects back.
    static func editableText(forMinorUnits minorUnits: Int64) -> String {
        let decimal = Decimal(minorUnits) / 100
        return decimal.formatted(
            .number.precision(.fractionLength(2)).grouping(.never).locale(Locale(identifier: "en_US_POSIX"))
        )
    }
}
