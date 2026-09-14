import Foundation
import SwiftData

/// Tracks when a resource collection (all of a user's accounts, or all of
/// a user's transactions) was last successfully refreshed from the server —
/// kept separate from the business records themselves rather than adding a
/// `lastSyncedAt` field to every `AccountRecord`/`TransactionRecord`, since
/// P0 has no offline mutation queue and only needs collection-level
/// freshness, not per-row sync state.
@Model
final class CacheMetadataRecord {
    enum Resource: String, Sendable {
        case accounts
        case transactions
        case walletProfile
    }

    /// `"<resource>:<userID>"`, e.g. `"accounts:20e9b6f4-..."`.
    @Attribute(.unique) var key: String
    var userID: UUID
    var resourceRawValue: String
    var lastSuccessfulSyncAt: Date

    init(userID: UUID, resourceRawValue: String, lastSuccessfulSyncAt: Date) {
        self.key = Self.key(userID: userID, resourceRawValue: resourceRawValue)
        self.userID = userID
        self.resourceRawValue = resourceRawValue
        self.lastSuccessfulSyncAt = lastSuccessfulSyncAt
    }

    static func key(userID: UUID, resourceRawValue: String) -> String {
        "\(resourceRawValue):\(userID.uuidString)"
    }
}
