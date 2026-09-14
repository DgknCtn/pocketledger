import Foundation

enum TransactionMapper {
    enum MappingError: Error, Sendable, Equatable {
        case invalidKind(String)
        case invalidCategory(String)
        case invalidDate(String)
    }

    static func domain(from dto: TransactionDTO, currency: CurrencyCode) throws -> Transaction {
        guard let kind = TransactionKind(rawValue: dto.kind) else {
            throw MappingError.invalidKind(dto.kind)
        }

        let category: TransactionCategory?
        if let rawCategory = dto.category {
            guard let resolved = TransactionCategory(rawValue: rawCategory) else {
                throw MappingError.invalidCategory(rawCategory)
            }
            category = resolved
        } else {
            category = nil
        }

        guard let date = try? LocalDate(parsing: dto.transactionDate) else {
            throw MappingError.invalidDate(dto.transactionDate)
        }

        return Transaction(
            id: dto.id,
            kind: kind,
            sourceAccountID: dto.accountID,
            destinationAccountID: dto.destinationAccountID,
            amount: Money(minorUnits: dto.amountMinor, currency: currency),
            category: category,
            title: dto.title,
            note: dto.note,
            date: date,
            createdAt: dto.createdAt,
            updatedAt: dto.updatedAt
        )
    }
}

extension CreateTransactionRequestDTO {
    init(input: NewTransaction, userID: UUID) {
        self.init(
            id: input.id,
            userID: userID,
            kind: input.kind.rawValue,
            accountID: input.sourceAccountID,
            destinationAccountID: input.destinationAccountID,
            amountMinor: input.amount.minorUnits,
            category: input.category?.rawValue,
            title: input.title,
            note: input.note,
            transactionDate: input.date.isoString
        )
    }
}

extension UpdateTransactionRequestDTO {
    init(input: NewTransaction) {
        self.init(
            kind: input.kind.rawValue,
            accountID: input.sourceAccountID,
            destinationAccountID: input.destinationAccountID,
            amountMinor: input.amount.minorUnits,
            category: input.category?.rawValue,
            title: input.title,
            note: input.note,
            transactionDate: input.date.isoString
        )
    }
}
