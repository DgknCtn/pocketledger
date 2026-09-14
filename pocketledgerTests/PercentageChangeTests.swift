import Testing
@testable import pocketledger

struct PercentageChangeTests {
    private let currency = CurrencyCode(rawValue: "TRY")!

    private func money(_ minorUnits: Int64) -> Money {
        Money(minorUnits: minorUnits, currency: currency)
    }

    @Test func increaseIsPositive() {
        let percent = PercentageChange.compute(current: money(12_000), previous: money(10_000))

        #expect(percent == 20)
    }

    @Test func decreaseIsNegative() {
        let percent = PercentageChange.compute(current: money(8_000), previous: money(10_000))

        #expect(percent == -20)
    }

    @Test func zeroPreviousValueReturnsNilInsteadOfDivisionByZero() {
        let percent = PercentageChange.compute(current: money(1_000), previous: money(0))

        #expect(percent == nil)
    }

    @Test func differentCurrenciesReturnNilRatherThanAMeaninglessComparison() {
        let usd = CurrencyCode(rawValue: "USD")!
        let percent = PercentageChange.compute(
            current: money(1_000),
            previous: Money(minorUnits: 1_000, currency: usd)
        )

        #expect(percent == nil)
    }

    /// Regression test: this exact scenario (434 vs 839, a ~48.27% decrease)
    /// was observed producing 0 in the running app due to
    /// `NSDecimalNumber.intValue` silently misconverting a `Decimal` with
    /// ~36 digits of fractional precision from raw `Decimal` division —
    /// see `PercentageChange`'s doc comment.
    @Test func highPrecisionDivisionDoesNotSilentlyRoundToZero() {
        let percent = PercentageChange.compute(current: money(43_400), previous: money(83_900))

        #expect(percent == -48)
    }

    @Test func sameValueProducesZero() {
        let percent = PercentageChange.compute(current: money(5_000), previous: money(5_000))

        #expect(percent == 0)
    }
}
