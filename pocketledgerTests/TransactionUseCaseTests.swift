import Foundation
import Testing
@testable import pocketledger

struct CreateTransactionUseCaseTests {
    private let currency = CurrencyCode(rawValue: "TRY")!

    @Test func validExpenseIsCreated() async throws {
        let repository = FakeTransactionRepository()
        let useCase = CreateTransactionUseCase(transactionRepository: repository)

        let transaction = try await useCase.execute(
            kind: .expense, sourceAccountID: UUID(), destinationAccountID: nil,
            amount: Money(minorUnits: 5_000, currency: currency), category: .food,
            title: "Lunch", note: nil, date: try LocalDate(parsing: "2026-09-14")
        )

        #expect(transaction.title == "Lunch")
        #expect(transaction.category == .food)
    }

    @Test func invalidTransactionThrowsBeforeReachingTheRepository() async {
        let repository = FakeTransactionRepository()
        let useCase = CreateTransactionUseCase(transactionRepository: repository)

        await #expect(throws: TransactionValidationError.categoryRequiredForExpense) {
            try await useCase.execute(
                kind: .expense, sourceAccountID: UUID(), destinationAccountID: nil,
                amount: Money(minorUnits: 5_000, currency: currency), category: nil,
                title: "Lunch", note: nil, date: try LocalDate(parsing: "2026-09-14")
            )
        }
    }
}

struct UpdateTransactionUseCaseTests {
    private let currency = CurrencyCode(rawValue: "TRY")!

    @Test func validEditIsSubmitted() async throws {
        let repository = FakeTransactionRepository()
        let useCase = UpdateTransactionUseCase(transactionRepository: repository)
        let id = UUID()

        let transaction = try await useCase.execute(
            id: id, kind: .expense, sourceAccountID: UUID(), destinationAccountID: nil,
            amount: Money(minorUnits: 7_500, currency: currency), category: .shopping,
            title: "Updated", note: nil, date: try LocalDate(parsing: "2026-09-14")
        )

        #expect(transaction.id == id)
        #expect(transaction.amount.minorUnits == 7_500)
    }

    @Test func transferToSameAccountFailsValidation() async {
        let repository = FakeTransactionRepository()
        let useCase = UpdateTransactionUseCase(transactionRepository: repository)
        let accountID = UUID()

        await #expect(throws: TransactionValidationError.transferSourceAndDestinationMustDiffer) {
            try await useCase.execute(
                id: UUID(), kind: .transfer, sourceAccountID: accountID, destinationAccountID: accountID,
                amount: Money(minorUnits: 1_000, currency: currency), category: nil,
                title: "Bad transfer", note: nil, date: try LocalDate(parsing: "2026-09-14")
            )
        }
    }
}
