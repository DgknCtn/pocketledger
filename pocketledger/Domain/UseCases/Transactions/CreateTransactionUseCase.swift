import Foundation

struct CreateTransactionUseCase {
    let transactionRepository: TransactionRepository

    func execute(
        kind: TransactionKind,
        sourceAccountID: UUID,
        destinationAccountID: UUID?,
        amount: Money,
        category: TransactionCategory?,
        title: String,
        note: String?,
        date: LocalDate
    ) async throws -> Transaction {
        let input = NewTransaction(
            id: UUID(),
            kind: kind,
            sourceAccountID: sourceAccountID,
            destinationAccountID: destinationAccountID,
            amount: amount,
            category: category,
            title: title,
            note: note,
            date: date
        )
        try TransactionValidator.validate(input)
        return try await transactionRepository.createTransaction(input)
    }
}
