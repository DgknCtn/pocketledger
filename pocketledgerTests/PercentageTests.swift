import Testing
@testable import pocketledger

struct PercentageTests {
    private let currency = CurrencyCode(rawValue: "TRY")!

    private func money(_ minorUnits: Int64) -> Money {
        Money(minorUnits: minorUnits, currency: currency)
    }

    // MARK: - changeFrom(previous:to:)

    @Test func increaseIsPositive() {
        let percent = Percentage.changeFrom(previous: money(10_000), to: money(12_000))

        #expect(percent == 20)
    }

    @Test func decreaseIsNegative() {
        let percent = Percentage.changeFrom(previous: money(10_000), to: money(8_000))

        #expect(percent == -20)
    }

    @Test func changeWithZeroPreviousValueReturnsNilInsteadOfDivisionByZero() {
        let percent = Percentage.changeFrom(previous: money(0), to: money(1_000))

        #expect(percent == nil)
    }

    @Test func changeWithDifferentCurrenciesReturnsNil() {
        let usd = CurrencyCode(rawValue: "USD")!
        let percent = Percentage.changeFrom(previous: money(1_000), to: Money(minorUnits: 1_000, currency: usd))

        #expect(percent == nil)
    }

    /// Regression test: this exact scenario (434 vs 839, a ~48.27% decrease)
    /// was observed producing 0 in the running app due to
    /// `NSDecimalNumber.intValue` silently misconverting a `Decimal` with
    /// ~36 digits of fractional precision from raw `Decimal` division —
    /// see `Percentage`'s doc comment.
    @Test func highPrecisionDivisionDoesNotSilentlyRoundToZero() {
        let percent = Percentage.changeFrom(previous: money(83_900), to: money(43_400))

        #expect(percent == -48)
    }

    @Test func sameValueProducesZeroChange() {
        let percent = Percentage.changeFrom(previous: money(5_000), to: money(5_000))

        #expect(percent == 0)
    }

    // MARK: - shareOfTotal(part:total:)

    @Test func shareOfTotalComputesAPlainPercentage() {
        let percent = Percentage.shareOfTotal(part: money(2_500), total: money(10_000))

        #expect(percent == 25)
    }

    @Test func shareOfZeroTotalReturnsNil() {
        let percent = Percentage.shareOfTotal(part: money(1_000), total: money(0))

        #expect(percent == nil)
    }

    @Test func shareOfTotalWithDifferentCurrenciesReturnsNil() {
        let usd = CurrencyCode(rawValue: "USD")!
        let percent = Percentage.shareOfTotal(part: Money(minorUnits: 1_000, currency: usd), total: money(10_000))

        #expect(percent == nil)
    }

    @Test func shareOfTotalHighPrecisionDoesNotRoundToZero() {
        // 434 / 839 ≈ 51.72% — division that yields the same kind of
        // high-precision Decimal as the regression above.
        let percent = Percentage.shareOfTotal(part: money(43_400), total: money(83_900))

        #expect(percent == 52)
    }
}
