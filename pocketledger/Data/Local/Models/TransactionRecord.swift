import Foundation
import SwiftData

@Model
final class TransactionRecord {
    @Attribute(.unique) var id: UUID
    var userID: UUID
    var kindRawValue: String
    var accountID: UUID
    var destinationAccountID: UUID?
    var amountMinor: Int64
    var categoryRawValue: String?
    var title: String
    var note: String?
    /// `"YYYY-MM-DD"` — the same calendar-date string PostgreSQL/PostgREST
    /// use, not a midnight `Date`. Keeping it a string avoids introducing
    /// timezone semantics into a calendar-date field, and ISO date strings
    /// sort lexicographically in chronological order (see `LocalDate`).
    var transactionDateKey: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID,
        userID: UUID,
        kindRawValue: String,
        accountID: UUID,
        destinationAccountID: UUID?,
        amountMinor: Int64,
        categoryRawValue: String?,
        title: String,
        note: String?,
        transactionDateKey: String,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.userID = userID
        self.kindRawValue = kindRawValue
        self.accountID = accountID
        self.destinationAccountID = destinationAccountID
        self.amountMinor = amountMinor
        self.categoryRawValue = categoryRawValue
        self.title = title
        self.note = note
        self.transactionDateKey = transactionDateKey
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension TransactionRecord {
    func toDomain(currency: CurrencyCode) throws -> Transaction {
        guard let kind = TransactionKind(rawValue: kindRawValue) else {
            throw PersistenceError.corruptedRecord
        }

        let category: TransactionCategory?
        if let categoryRawValue {
            guard let resolved = TransactionCategory(rawValue: categoryRawValue) else {
                throw PersistenceError.corruptedRecord
            }
            category = resolved
        } else {
            category = nil
        }

        guard let date = try? LocalDate(parsing: transactionDateKey) else {
            throw PersistenceError.corruptedRecord
        }

        return Transaction(
            id: id,
            kind: kind,
            sourceAccountID: accountID,
            destinationAccountID: destinationAccountID,
            amount: Money(minorUnits: amountMinor, currency: currency),
            category: category,
            title: title,
            note: note,
            date: date,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    convenience init(transaction: Transaction, userID: UUID) {
        self.init(
            id: transaction.id,
            userID: userID,
            kindRawValue: transaction.kind.rawValue,
            accountID: transaction.sourceAccountID,
            destinationAccountID: transaction.destinationAccountID,
            amountMinor: transaction.amount.minorUnits,
            categoryRawValue: transaction.category?.rawValue,
            title: transaction.title,
            note: transaction.note,
            transactionDateKey: transaction.date.isoString,
            createdAt: transaction.createdAt,
            updatedAt: transaction.updatedAt
        )
    }

    func update(from transaction: Transaction) {
        kindRawValue = transaction.kind.rawValue
        accountID = transaction.sourceAccountID
        destinationAccountID = transaction.destinationAccountID
        amountMinor = transaction.amount.minorUnits
        categoryRawValue = transaction.category?.rawValue
        title = transaction.title
        note = transaction.note
        transactionDateKey = transaction.date.isoString
        updatedAt = transaction.updatedAt
    }
}
