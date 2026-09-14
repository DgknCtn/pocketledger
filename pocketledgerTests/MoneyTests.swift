import Foundation
import Testing
@testable import pocketledger

struct MoneyTests {
    private let try_ = CurrencyCode(rawValue: "TRY")!
    private let usd = CurrencyCode(rawValue: "USD")!

    @Test func addingSameCurrencySucceeds() throws {
        let a = Money(minorUnits: 100, currency: try_)
        let b = Money(minorUnits: 200, currency: try_)

        let result = try a.adding(b)

        #expect(result.minorUnits == 300)
        #expect(result.currency == try_)
    }

    @Test func subtractingCanGoNegative() throws {
        let a = Money(minorUnits: 100, currency: try_)
        let b = Money(minorUnits: 200, currency: try_)

        let result = try a.subtracting(b)

        #expect(result.minorUnits == -100)
        #expect(result.isNegative)
    }

    @Test func addingDifferentCurrenciesThrows() {
        let a = Money(minorUnits: 100, currency: try_)
        let b = Money(minorUnits: 100, currency: usd)

        #expect(throws: Money.CurrencyMismatchError.mismatch(try_, usd)) {
            try a.adding(b)
        }
    }

    @Test func subtractingDifferentCurrenciesThrows() {
        let a = Money(minorUnits: 100, currency: try_)
        let b = Money(minorUnits: 100, currency: usd)

        #expect(throws: Money.CurrencyMismatchError.mismatch(try_, usd)) {
            try a.subtracting(b)
        }
    }

    @Test func zeroIsZeroAndNotNegative() {
        let zero = Money.zero(currency: try_)

        #expect(zero.isZero)
        #expect(!zero.isNegative)
    }

    @Test func decimalValueConvertsMinorUnitsToTwoDecimalPlaces() {
        let money = Money(minorUnits: 424_250, currency: try_)

        #expect(money.decimalValue == Decimal(string: "4242.50")!)
    }

    @Test func sumReducesAMixOfPositiveAndNegativeValues() throws {
        let values = [
            Money(minorUnits: 1_000_000, currency: try_),
            Money(minorUnits: 500_000, currency: try_),
            Money(minorUnits: -200_000, currency: try_),
            Money(minorUnits: -100_000, currency: try_),
            Money(minorUnits: 50_000, currency: try_),
        ]

        let total = try Money.sum(values, currency: try_)

        #expect(total.minorUnits == 1_250_000)
    }

    @Test func sumOfEmptySequenceIsZero() throws {
        let total = try Money.sum([Money](), currency: try_)

        #expect(total.isZero)
    }

    @Test func negatedFlipsSign() {
        let money = Money(minorUnits: 500, currency: try_)

        #expect(money.negated.minorUnits == -500)
        #expect(money.negated.negated == money)
    }

    @Test func comparisonOrdersBySameCurrencyMinorUnits() {
        let smaller = Money(minorUnits: 100, currency: try_)
        let larger = Money(minorUnits: 200, currency: try_)

        #expect(smaller < larger)
        #expect(!(larger < smaller))
    }

    @Test func largeValuesRemainExact() throws {
        // Comfortably within Int64 range; guards against any accidental
        // truncation to a smaller integer type or a Double round-trip.
        let a = Money(minorUnits: 9_000_000_000_000, currency: try_)
        let b = Money(minorUnits: 1, currency: try_)

        let result = try a.adding(b)

        #expect(result.minorUnits == 9_000_000_000_001)
    }
}
