import Foundation
import SwiftData

@Model
final class AccountRecord {
    @Attribute(.unique) var id: UUID
    var userID: UUID
    var name: String
    var kindRawValue: String
    var openingBalanceMinor: Int64
    var isArchived: Bool
    var archivedAt: Date?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID,
        userID: UUID,
        name: String,
        kindRawValue: String,
        openingBalanceMinor: Int64,
        isArchived: Bool,
        archivedAt: Date?,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.userID = userID
        self.name = name
        self.kindRawValue = kindRawValue
        self.openingBalanceMinor = openingBalanceMinor
        self.isArchived = isArchived
        self.archivedAt = archivedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension AccountRecord {
    /// The cache stores accounts scoped to a single base currency (see the
    /// database specification's single-base-currency P0 decision), so the
    /// currency comes from the caller rather than being stored per-row.
    func toDomain(currency: CurrencyCode) throws -> Account {
        guard let kind = AccountKind(rawValue: kindRawValue) else {
            throw PersistenceError.corruptedRecord
        }
        return Account(
            id: id,
            name: name,
            kind: kind,
            openingBalance: Money(minorUnits: openingBalanceMinor, currency: currency),
            isArchived: isArchived,
            archivedAt: archivedAt,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    convenience init(account: Account, userID: UUID) {
        self.init(
            id: account.id,
            userID: userID,
            name: account.name,
            kindRawValue: account.kind.rawValue,
            openingBalanceMinor: account.openingBalance.minorUnits,
            isArchived: account.isArchived,
            archivedAt: account.archivedAt,
            createdAt: account.createdAt,
            updatedAt: account.updatedAt
        )
    }

    func update(from account: Account) {
        name = account.name
        kindRawValue = account.kind.rawValue
        openingBalanceMinor = account.openingBalance.minorUnits
        isArchived = account.isArchived
        archivedAt = account.archivedAt
        updatedAt = account.updatedAt
    }
}
