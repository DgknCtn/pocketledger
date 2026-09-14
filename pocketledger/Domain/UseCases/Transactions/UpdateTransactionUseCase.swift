import Foundation

struct UpdateTransactionUseCase {
    let transactionRepository: TransactionRepository

    func execute(
        id: UUID,
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
            id: id,
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
        return try await transactionRepository.updateTransaction(id: id, input: input)
    }
}
