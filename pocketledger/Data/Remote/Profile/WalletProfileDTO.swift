import Foundation

struct WalletProfileDTO: Codable, Sendable {
    let userID: UUID
    let baseCurrencyCode: String
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case baseCurrencyCode = "base_currency_code"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct CreateWalletProfileRequestDTO: Encodable, Sendable {
    let userID: UUID
    let baseCurrencyCode: String

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case baseCurrencyCode = "base_currency_code"
    }
}
