import Foundation

/// An exact monetary amount, stored as integer minor units (e.g. cents/kuruş)
/// rather than a binary floating-point type.
///
/// `Double` is never used for money in this app: binary floating-point
/// values cannot represent every decimal fraction exactly, which is
/// unacceptable for financial arithmetic. `Int64` minor units give an exact,
/// trivially `Codable` representation that matches the remote
/// `amount_minor` / `opening_balance_minor` columns one-to-one.
struct Money: Hashable, Sendable {
    /// Two currency values were combined despite having different
    /// currencies. In this P0 (single base-currency) app, hitting this is
    /// always a programmer error / data-integrity bug, never a user-facing
    /// scenario — but it is still a thrown error rather than a silent wrong
    /// answer or a crash.
    enum CurrencyMismatchError: Error, Equatable, Sendable {
        case mismatch(CurrencyCode, CurrencyCode)
    }

    let minorUnits: Int64
    let currency: CurrencyCode

    init(minorUnits: Int64, currency: CurrencyCode) {
        self.minorUnits = minorUnits
        self.currency = currency
    }

    static func zero(currency: CurrencyCode) -> Money {
        Money(minorUnits: 0, currency: currency)
    }

    var isZero: Bool { minorUnits == 0 }
    var isNegative: Bool { minorUnits < 0 }

    var negated: Money {
        Money(minorUnits: -minorUnits, currency: currency)
    }

    /// The value as a `Decimal`, for display formatting only. Every P0
    /// currency (TRY, USD, EUR, GBP) uses 2 minor-unit digits.
    var decimalValue: Decimal {
        Decimal(minorUnits) / 100
    }

    func adding(_ other: Money) throws -> Money {
        guard currency == other.currency else {
            throw CurrencyMismatchError.mismatch(currency, other.currency)
        }
        return Money(minorUnits: minorUnits + other.minorUnits, currency: currency)
    }

    func subtracting(_ other: Money) throws -> Money {
        guard currency == other.currency else {
            throw CurrencyMismatchError.mismatch(currency, other.currency)
        }
        return Money(minorUnits: minorUnits - other.minorUnits, currency: currency)
    }

    static func sum(_ values: some Sequence<Money>, currency: CurrencyCode) throws -> Money {
        try values.reduce(Money.zero(currency: currency)) { try $0.adding($1) }
    }
}

extension Money: Comparable {
    static func < (lhs: Money, rhs: Money) -> Bool {
        precondition(
            lhs.currency == rhs.currency,
            "Cannot compare Money values in different currencies"
        )
        return lhs.minorUnits < rhs.minorUnits
    }
}
