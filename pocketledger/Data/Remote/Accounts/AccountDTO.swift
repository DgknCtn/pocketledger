import Foundation

struct AccountDTO: Codable, Sendable {
    let id: UUID
    let userID: UUID
    let name: String
    let kind: String
    let openingBalanceMinor: Int64
    let isArchived: Bool
    let archivedAt: Date?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case name
        case kind
        case openingBalanceMinor = "opening_balance_minor"
        case isArchived = "is_archived"
        case archivedAt = "archived_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct CreateAccountRequestDTO: Encodable, Sendable {
    let id: UUID
    let userID: UUID
    let name: String
    let kind: String
    let openingBalanceMinor: Int64

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case name
        case kind
        case openingBalanceMinor = "opening_balance_minor"
    }
}

/// Carries the account's complete mutable state, including archive fields —
/// archiving is just a state transition on the same resource, not a
/// separate endpoint (see the API specification).
struct UpdateAccountRequestDTO: Encodable, Sendable {
    let name: String
    let openingBalanceMinor: Int64
    let isArchived: Bool
    let archivedAt: Date?

    enum CodingKeys: String, CodingKey {
        case name
        case openingBalanceMinor = "opening_balance_minor"
        case isArchived = "is_archived"
        case archivedAt = "archived_at"
    }
}
