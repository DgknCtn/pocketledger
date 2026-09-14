import Foundation

/// Converts between `AccountDTO` (remote wire format) and `Account`
/// (Domain). Pure functions — no networking, no persistence, no UI state —
/// so mapping bugs are caught by fast unit tests, not integration tests.
enum AccountMapper {
    enum MappingError: Error, Sendable, Equatable {
        case invalidKind(String)
    }

    /// P0 accounts are always denominated in the wallet's single base
    /// currency (see the database specification), which is why `currency`
    /// is supplied by the caller rather than being part of `AccountDTO`.
    static func domain(from dto: AccountDTO, currency: CurrencyCode) throws -> Account {
        guard let kind = AccountKind(rawValue: dto.kind) else {
            throw MappingError.invalidKind(dto.kind)
        }

        return Account(
            id: dto.id,
            name: dto.name,
            kind: kind,
            openingBalance: Money(minorUnits: dto.openingBalanceMinor, currency: currency),
            isArchived: dto.isArchived,
            archivedAt: dto.archivedAt,
            createdAt: dto.createdAt,
            updatedAt: dto.updatedAt
        )
    }
}

extension CreateAccountRequestDTO {
    init(input: CreateAccountInput, userID: UUID) {
        self.init(
            id: input.id,
            userID: userID,
            name: input.name,
            kind: input.kind.rawValue,
            openingBalanceMinor: input.openingBalance.minorUnits
        )
    }
}

extension UpdateAccountRequestDTO {
    init(input: UpdateAccountInput, isArchived: Bool, archivedAt: Date?) {
        self.init(
            name: input.name,
            openingBalanceMinor: input.openingBalance.minorUnits,
            isArchived: isArchived,
            archivedAt: archivedAt
        )
    }

    /// Convenience for a pure state-transition update (archive/unarchive)
    /// that does not otherwise change the account.
    init(account: Account, isArchived: Bool, archivedAt: Date?) {
        self.init(
            name: account.name,
            openingBalanceMinor: account.openingBalance.minorUnits,
            isArchived: isArchived,
            archivedAt: archivedAt
        )
    }
}
