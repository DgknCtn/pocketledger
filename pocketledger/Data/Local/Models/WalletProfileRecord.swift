import Foundation
import SwiftData

@Model
final class WalletProfileRecord {
    @Attribute(.unique) var userID: UUID
    var baseCurrencyCode: String
    var createdAt: Date
    var updatedAt: Date

    init(userID: UUID, baseCurrencyCode: String, createdAt: Date, updatedAt: Date) {
        self.userID = userID
        self.baseCurrencyCode = baseCurrencyCode
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension WalletProfileRecord {
    /// Never crosses the `PersistenceActor` boundary itself — only the
    /// `WalletProfile` this produces does (see the Architecture
    /// specification's rule against passing `@Model` objects across actor
    /// boundaries).
    func toDomain() throws -> WalletProfile {
        guard let currency = CurrencyCode(rawValue: baseCurrencyCode) else {
            throw PersistenceError.corruptedRecord
        }
        return WalletProfile(baseCurrency: currency)
    }

    func update(from profile: WalletProfile, updatedAt: Date) {
        self.baseCurrencyCode = profile.baseCurrency.rawValue
        self.updatedAt = updatedAt
    }
}
