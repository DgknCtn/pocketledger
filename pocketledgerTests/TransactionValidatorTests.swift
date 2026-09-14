import Foundation
import Testing
@testable import pocketledger

struct TransactionValidatorTests {
    private let currency = CurrencyCode(rawValue: "TRY")!
    private let today = try! LocalDate(parsing: "2026-09-14")

    private func makeAccountID() -> UUID { UUID() }

    private func draft(
        kind: TransactionKind,
        source: UUID,
        destination: UUID? = nil,
        amountMinor: Int64 = 1_000,
        category: TransactionCategory? = nil,
        title: String = "Lunch",
        date: LocalDate? = nil
    ) -> NewTransaction {
        NewTransaction(
            id: UUID(),
            kind: kind,
            sourceAccountID: source,
            destinationAccountID: destination,
            amount: Money(minorUnits: amountMinor, currency: currency),
            category: category,
            title: title,
            note: nil,
            date: date ?? today
        )
    }

    // MARK: - Valid transactions

    @Test func validExpenseSucceeds() throws {
        let account = makeAccountID()
        let transaction = draft(kind: .expense, source: account, category: .food)

        try TransactionValidator.validate(transaction, today: today)
    }

    @Test func validIncomeSucceeds() throws {
        let account = makeAccountID()
        let transaction = draft(kind: .income, source: account)

        try TransactionValidator.validate(transaction, today: today)
    }

    @Test func validTransferSucceeds() throws {
        let source = makeAccountID()
        let destination = makeAccountID()
        let transaction = draft(kind: .transfer, source: source, destination: destination)

        try TransactionValidator.validate(transaction, today: today)
    }

    @Test func transactionDatedTodayIsAllowed() throws {
        let account = makeAccountID()
        let transaction = draft(kind: .income, source: account, date: today)

        try TransactionValidator.validate(transaction, today: today)
    }

    // MARK: - Amount

    @Test func zeroAmountFails() {
        let account = makeAccountID()
        let transaction = draft(kind: .income, source: account, amountMinor: 0)

        #expect(throws: TransactionValidationError.amountMustBePositive) {
            try TransactionValidator.validate(transaction, today: today)
        }
    }

    @Test func negativeAmountFails() {
        let account = makeAccountID()
        let transaction = draft(kind: .income, source: account, amountMinor: -500)

        #expect(throws: TransactionValidationError.amountMustBePositive) {
            try TransactionValidator.validate(transaction, today: today)
        }
    }

    // MARK: - Title

    @Test func emptyTitleFails() {
        let account = makeAccountID()
        let transaction = draft(kind: .income, source: account, title: "")

        #expect(throws: TransactionValidationError.titleRequired) {
            try TransactionValidator.validate(transaction, today: today)
        }
    }

    @Test func whitespaceOnlyTitleFails() {
        let account = makeAccountID()
        let transaction = draft(kind: .income, source: account, title: "   ")

        #expect(throws: TransactionValidationError.titleRequired) {
            try TransactionValidator.validate(transaction, today: today)
        }
    }

    // MARK: - Date

    @Test func futureDatedTransactionFails() throws {
        let account = makeAccountID()
        let tomorrow = try LocalDate(parsing: "2026-09-15")
        let transaction = draft(kind: .income, source: account, date: tomorrow)

        #expect(throws: TransactionValidationError.futureDateNotAllowed) {
            try TransactionValidator.validate(transaction, today: today)
        }
    }

    // MARK: - Expense shape

    @Test func expenseWithoutCategoryFails() {
        let account = makeAccountID()
        let transaction = draft(kind: .expense, source: account, category: nil)

        #expect(throws: TransactionValidationError.categoryRequiredForExpense) {
            try TransactionValidator.validate(transaction, today: today)
        }
    }

    @Test func expenseWithDestinationAccountFails() {
        let source = makeAccountID()
        let destination = makeAccountID()
        let transaction = draft(
            kind: .expense,
            source: source,
            destination: destination,
            category: .food
        )

        #expect(throws: TransactionValidationError.destinationAccountNotAllowedForThisKind) {
            try TransactionValidator.validate(transaction, today: today)
        }
    }

    // MARK: - Income shape

    @Test func incomeWithCategoryFails() {
        let account = makeAccountID()
        let transaction = draft(kind: .income, source: account, category: .shopping)

        #expect(throws: TransactionValidationError.categoryNotAllowedForIncome) {
            try TransactionValidator.validate(transaction, today: today)
        }
    }

    @Test func incomeWithDestinationAccountFails() {
        let source = makeAccountID()
        let destination = makeAccountID()
        let transaction = draft(kind: .income, source: source, destination: destination)

        #expect(throws: TransactionValidationError.destinationAccountNotAllowedForThisKind) {
            try TransactionValidator.validate(transaction, today: today)
        }
    }

    // MARK: - Transfer shape

    @Test func transferWithoutDestinationFails() {
        let account = makeAccountID()
        let transaction = draft(kind: .transfer, source: account, destination: nil)

        #expect(throws: TransactionValidationError.destinationAccountRequiredForTransfer) {
            try TransactionValidator.validate(transaction, today: today)
        }
    }

    @Test func transferToSameAccountFails() {
        let account = makeAccountID()
        let transaction = draft(kind: .transfer, source: account, destination: account)

        #expect(throws: TransactionValidationError.transferSourceAndDestinationMustDiffer) {
            try TransactionValidator.validate(transaction, today: today)
        }
    }

    @Test func transferWithCategoryFails() {
        let source = makeAccountID()
        let destination = makeAccountID()
        let transaction = draft(
            kind: .transfer,
            source: source,
            destination: destination,
            category: .bills
        )

        #expect(throws: TransactionValidationError.categoryNotAllowedForTransfer) {
            try TransactionValidator.validate(transaction, today: today)
        }
    }
}
