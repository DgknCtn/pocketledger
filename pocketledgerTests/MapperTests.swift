import Foundation
import Testing
@testable import pocketledger

struct AccountMapperTests {
    private let currency = CurrencyCode(rawValue: "TRY")!
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func dto(kind: String = "bank", isArchived: Bool = false, archivedAt: Date? = nil) -> AccountDTO {
        AccountDTO(
            id: UUID(), userID: UUID(), name: "Main", kind: kind,
            openingBalanceMinor: 1_000, isArchived: isArchived, archivedAt: archivedAt,
            createdAt: now, updatedAt: now
        )
    }

    @Test func validDTOMapsToDomain() throws {
        let account = try AccountMapper.domain(from: dto(kind: "credit_card"), currency: currency)

        #expect(account.kind == .creditCard)
        #expect(account.openingBalance.minorUnits == 1_000)
    }

    @Test func invalidKindThrowsMappingError() {
        #expect(throws: AccountMapper.MappingError.invalidKind("not_a_kind")) {
            try AccountMapper.domain(from: dto(kind: "not_a_kind"), currency: currency)
        }
    }
}

struct TransactionMapperTests {
    private let currency = CurrencyCode(rawValue: "TRY")!
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func dto(
        kind: String = "expense",
        category: String? = "food",
        transactionDate: String = "2026-09-14"
    ) -> TransactionDTO {
        TransactionDTO(
            id: UUID(), userID: UUID(), kind: kind, accountID: UUID(), destinationAccountID: nil,
            amountMinor: 5_000, category: category, title: "Lunch", note: nil,
            transactionDate: transactionDate, createdAt: now, updatedAt: now
        )
    }

    @Test func validDTOMapsToDomain() throws {
        let transaction = try TransactionMapper.domain(from: dto(), currency: currency)

        #expect(transaction.kind == .expense)
        #expect(transaction.category == .food)
        #expect(transaction.date.isoString == "2026-09-14")
    }

    @Test func invalidKindThrowsMappingError() {
        #expect(throws: TransactionMapper.MappingError.invalidKind("not_a_kind")) {
            try TransactionMapper.domain(from: dto(kind: "not_a_kind"), currency: currency)
        }
    }

    @Test func invalidCategoryThrowsMappingError() {
        #expect(throws: TransactionMapper.MappingError.invalidCategory("not_a_category")) {
            try TransactionMapper.domain(from: dto(category: "not_a_category"), currency: currency)
        }
    }

    @Test func invalidDateThrowsMappingError() {
        #expect(throws: TransactionMapper.MappingError.invalidDate("not-a-date")) {
            try TransactionMapper.domain(from: dto(transactionDate: "not-a-date"), currency: currency)
        }
    }

    @Test func incomeWithNilCategoryMapsCleanly() throws {
        let transaction = try TransactionMapper.domain(from: dto(kind: "income", category: nil), currency: currency)

        #expect(transaction.category == nil)
    }
}
