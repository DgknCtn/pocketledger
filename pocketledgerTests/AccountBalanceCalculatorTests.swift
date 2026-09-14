import Foundation
import Testing
@testable import pocketledger

struct AccountBalanceCalculatorTests {
    private let currency = CurrencyCode(rawValue: "TRY")!
    private let date = try! LocalDate(parsing: "2026-09-14")

    private func makeAccount(openingMinor: Int64) -> Account {
        Account(
            id: UUID(),
            name: "Test Account",
            kind: .bank,
            openingBalance: Money(minorUnits: openingMinor, currency: currency),
            isArchived: false,
            archivedAt: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    private func money(_ minorUnits: Int64) -> Money {
        Money(minorUnits: minorUnits, currency: currency)
    }

    private func transaction(
        kind: TransactionKind,
        source: UUID,
        destination: UUID? = nil,
        amountMinor: Int64,
        category: TransactionCategory? = nil
    ) -> Transaction {
        Transaction(
            id: UUID(),
            kind: kind,
            sourceAccountID: source,
            destinationAccountID: destination,
            amount: money(amountMinor),
            category: category,
            title: "Transaction",
            note: nil,
            date: date,
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    /// Database specification §128: bank account with opening balance,
    /// income, expense and both directions of transfer.
    @Test func bankAccountBalanceMatchesOpeningPlusIncomeMinusExpensePlusNetTransfers() throws {
        let account = makeAccount(openingMinor: 1_000_000)
        let otherAccount = UUID()

        let transactions = [
            transaction(kind: .income, source: account.id, amountMinor: 500_000),
            transaction(kind: .expense, source: account.id, amountMinor: 200_000, category: .food),
            transaction(kind: .transfer, source: account.id, destination: otherAccount, amountMinor: 100_000),
            transaction(kind: .transfer, source: otherAccount, destination: account.id, amountMinor: 50_000),
        ]

        let balance = try AccountBalanceCalculator.balance(for: account, transactions: transactions)

        #expect(balance == money(1_250_000))
    }

    /// Database specification §130-131: a credit card's opening debt, a new
    /// expense increasing it, and deleting that expense (i.e. recalculating
    /// against a transaction list that no longer includes it) restoring the
    /// prior balance — proving balance is derived, never mutated directly.
    @Test func creditCardExpenseIncreasesDebtAndDeletionReversesIt() throws {
        let account = makeAccount(openingMinor: -200_000)
        let expense = transaction(
            kind: .expense,
            source: account.id,
            amountMinor: 50_000,
            category: .shopping
        )

        let balanceAfterExpense = try AccountBalanceCalculator.balance(
            for: account,
            transactions: [expense]
        )
        #expect(balanceAfterExpense == money(-250_000))

        let balanceAfterDeletingExpense = try AccountBalanceCalculator.balance(
            for: account,
            transactions: []
        )
        #expect(balanceAfterDeletingExpense == money(-200_000))
    }

    /// Database specification §129: a transfer changes both accounts'
    /// individual balances but leaves the sum of both accounts unchanged —
    /// it is money moving between the user's own accounts, not new wealth.
    @Test func transferPreservesCombinedTotalAcrossBothAccounts() throws {
        let bank = makeAccount(openingMinor: 1_000_000)
        let creditCard = makeAccount(openingMinor: -400_000)

        let transfer = transaction(
            kind: .transfer,
            source: bank.id,
            destination: creditCard.id,
            amountMinor: 200_000
        )

        let bankBalance = try AccountBalanceCalculator.balance(for: bank, transactions: [transfer])
        let creditCardBalance = try AccountBalanceCalculator.balance(for: creditCard, transactions: [transfer])

        #expect(bankBalance == money(800_000))
        #expect(creditCardBalance == money(-200_000))

        let totalBefore = try bank.openingBalance.adding(creditCard.openingBalance)
        let totalAfter = try bankBalance.adding(creditCardBalance)
        #expect(totalBefore == totalAfter)
    }

    @Test func transactionsBelongingToOtherAccountsAreIgnored() throws {
        let account = makeAccount(openingMinor: 100_000)
        let unrelatedAccount = UUID()

        let unrelatedExpense = transaction(
            kind: .expense,
            source: unrelatedAccount,
            amountMinor: 999_999,
            category: .food
        )

        let balance = try AccountBalanceCalculator.balance(
            for: account,
            transactions: [unrelatedExpense]
        )

        #expect(balance == account.openingBalance)
    }

    @Test func noTransactionsReturnsOpeningBalance() throws {
        let account = makeAccount(openingMinor: 42_000)

        let balance = try AccountBalanceCalculator.balance(for: account, transactions: [])

        #expect(balance == account.openingBalance)
    }

    @Test func currencyMismatchThrowsRatherThanProducingAWrongAnswer() {
        let account = makeAccount(openingMinor: 0)
        let usd = CurrencyCode(rawValue: "USD")!
        let mismatched = Transaction(
            id: UUID(),
            kind: .income,
            sourceAccountID: account.id,
            destinationAccountID: nil,
            amount: Money(minorUnits: 100, currency: usd),
            category: nil,
            title: "Mismatched",
            note: nil,
            date: date,
            createdAt: Date(),
            updatedAt: Date()
        )

        #expect(throws: (any Error).self) {
            try AccountBalanceCalculator.balance(for: account, transactions: [mismatched])
        }
    }
}
