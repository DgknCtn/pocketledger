import Foundation

struct TransactionDTO: Codable, Sendable {
    let id: UUID
    let userID: UUID
    let kind: String
    let accountID: UUID
    let destinationAccountID: UUID?
    let amountMinor: Int64
    let category: String?
    let title: String
    let note: String?
    /// `"YYYY-MM-DD"` — deliberately not decoded as `Date`, to avoid
    /// introducing timezone semantics into a calendar-date field.
    let transactionDate: String
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case kind
        case accountID = "account_id"
        case destinationAccountID = "destination_account_id"
        case amountMinor = "amount_minor"
        case category
        case title
        case note
        case transactionDate = "transaction_date"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct CreateTransactionRequestDTO: Encodable, Sendable {
    let id: UUID
    let userID: UUID
    let kind: String
    let accountID: UUID
    let destinationAccountID: UUID?
    let amountMinor: Int64
    let category: String?
    let title: String
    let note: String?
    let transactionDate: String

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case kind
        case accountID = "account_id"
        case destinationAccountID = "destination_account_id"
        case amountMinor = "amount_minor"
        case category
        case title
        case note
        case transactionDate = "transaction_date"
    }
}

/// Carries the transaction's complete mutable state (see
/// `UpdateAccountRequestDTO`'s doc comment for why — cross-field
/// invariants like "transfer requires a destination" need to be
/// expressible as one coherent intended state).
struct UpdateTransactionRequestDTO: Encodable, Sendable {
    let kind: String
    let accountID: UUID
    let destinationAccountID: UUID?
    let amountMinor: Int64
    let category: String?
    let title: String
    let note: String?
    let transactionDate: String

    enum CodingKeys: String, CodingKey {
        case kind
        case accountID = "account_id"
        case destinationAccountID = "destination_account_id"
        case amountMinor = "amount_minor"
        case category
        case title
        case note
        case transactionDate = "transaction_date"
    }
}
