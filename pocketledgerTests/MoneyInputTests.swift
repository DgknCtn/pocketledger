import Testing
@testable import pocketledger

struct MoneyInputTests {
    private let currency = CurrencyCode(rawValue: "TRY")!

    @Test func parsesADecimalAmount() {
        let money = MoneyInput.parse("1500.50", currency: currency)

        #expect(money?.minorUnits == 150_050)
    }

    @Test func parsesAWholeNumberAmount() {
        let money = MoneyInput.parse("42", currency: currency)

        #expect(money?.minorUnits == 4_200)
    }

    @Test func stripsThousandsSeparators() {
        let money = MoneyInput.parse("2,450.00", currency: currency)

        #expect(money?.minorUnits == 245_000)
    }

    @Test func rejectsNegativeAmounts() {
        #expect(MoneyInput.parse("-100", currency: currency) == nil)
    }

    @Test func rejectsNonNumericText() {
        #expect(MoneyInput.parse("abc", currency: currency) == nil)
    }

    @Test func rejectsEmptyText() {
        #expect(MoneyInput.parse("", currency: currency) == nil)
    }

    @Test func roundTripsThroughEditableText() {
        let text = MoneyInput.editableText(forMinorUnits: 424_250)

        #expect(text == "4242.50")
        #expect(MoneyInput.parse(text, currency: currency)?.minorUnits == 424_250)
    }
}
